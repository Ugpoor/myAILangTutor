import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// LLM 服务提供商枚举
enum LlmProvider { doubao, qwen }

/// 双渠道 LLM 服务：豆包（火山引擎 Ark Responses API）为主，千问（阿里百炼 OpenAI 兼容 API）为备。
/// 通过 .env 中的 ACTIVE_PROVIDER 切换（doubao / qwen），默认 doubao。
/// 当主渠道请求失败（网络异常或非 200 状态码）时，自动降级到备用渠道，保证服务可用性。
class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  static const int _defaultMaxTokens = 256000;
  static const double _defaultTemperature = 0.7;

  // 活跃渠道
  LlmProvider _activeProvider = LlmProvider.doubao;

  // 豆包配置
  String? _doubaoApiKey;
  String? _doubaoBaseUrl;
  String? _doubaoModelName;

  // 千问配置
  String? _qwenApiKey;
  String? _qwenBaseUrl;
  String? _qwenModelName;

  // 通用参数
  int _maxTokens = _defaultMaxTokens;
  double _temperature = _defaultTemperature;

  /// 当前活跃的提供商
  LlmProvider get activeProvider => _activeProvider;

  /// 当前活跃的模型名称
  String get activeModelName => _activeProvider == LlmProvider.qwen
      ? (_qwenModelName ?? 'qwen3.7-plus')
      : (_doubaoModelName ?? 'doubao-seed-2-0-mini-260428');

  /// 运行时切换渠道
  void switchProvider(LlmProvider provider) {
    _activeProvider = provider;
    if (kDebugMode) {
      debugPrint('[LlmService] 切换到: ${provider.name}, 模型: $activeModelName');
    }
  }

  Future<void> init() async {
    // 豆包配置
    _doubaoApiKey = dotenv.env['DOUBAO_API_KEY'] ?? dotenv.env['API_KEY'] ?? '';
    _doubaoBaseUrl = dotenv.env['DOUBAO_BASE_URL'] ?? dotenv.env['BASE_URL'] ?? 'https://ark.cn-beijing.volces.com/api/v3';
    _doubaoModelName = dotenv.env['DOUBAO_MODEL_NAME'] ?? dotenv.env['MODEL_NAME'] ?? 'doubao-seed-2-0-mini-260428';

    // 千问配置
    _qwenApiKey = dotenv.env['QWEN_API_KEY'] ?? '';
    _qwenBaseUrl = dotenv.env['QWEN_BASE_URL'] ?? 'https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1';
    _qwenModelName = dotenv.env['QWEN_MODEL_NAME'] ?? 'qwen3.7-plus';

    // 通用参数
    _maxTokens = int.tryParse(dotenv.env['MAX_TOKENS'] ?? '') ?? _defaultMaxTokens;
    _temperature = double.tryParse(dotenv.env['TEMPERATURE'] ?? '') ?? _defaultTemperature;

    // 活跃渠道
    final providerStr = (dotenv.env['ACTIVE_PROVIDER'] ?? 'doubao').toLowerCase().trim();
    _activeProvider = providerStr == 'doubao' ? LlmProvider.doubao : LlmProvider.qwen;

    if (kDebugMode) {
      debugPrint('[LlmService] 初始化完成 — 渠道: ${_activeProvider.name}, 模型: $activeModelName');
    }
  }

  // ========================= 公共 API（含自动降级）=========================

  /// 获取备用渠道
  LlmProvider get _fallbackProvider => _activeProvider == LlmProvider.doubao
      ? LlmProvider.qwen
      : LlmProvider.doubao;

  /// 判断结果是否为失败（需要降级）
  bool _isFailure(Map<String, dynamic> result) {
    return result['success'] != true;
  }

  /// 通用文本生成（含推理/思考），主渠道失败自动降级到备用渠道
  Future<Map<String, dynamic>> generateResponse(String prompt) async {
    // 尝试主渠道
    final primaryResult = _activeProvider == LlmProvider.qwen
        ? await _generateResponseQwen(prompt)
        : await _generateResponseDoubao(prompt);

    if (!_isFailure(primaryResult)) return primaryResult;

    // 主渠道失败，降级到备用渠道
    if (kDebugMode) {
      debugPrint('[LlmService] ${_activeProvider.name} 失败，自动降级到 ${_fallbackProvider.name}');
    }

    final fallbackResult = _fallbackProvider == LlmProvider.qwen
        ? await _generateResponseQwen(prompt)
        : await _generateResponseDoubao(prompt);

    // 在降级结果中附加降级标记
    if (fallbackResult['success'] == true) {
      fallbackResult['fallback'] = true;
      fallbackResult['fallback_provider'] = _fallbackProvider.name;
    }
    return fallbackResult;
  }

  /// 带工具定义的生成（当前委托给 generateResponse）
  Future<Map<String, dynamic>> generateResponseWithTools(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    bool toolChoice = false,
  }) async {
    return await generateResponse(prompt);
  }

  /// 测试工具调用（当前委托给 generateResponse）
  Future<Map<String, dynamic>> testToolCall(String prompt) async {
    return await generateResponse(prompt);
  }

  /// 结构化 JSON 输出（system + user 双 prompt），主渠道失败自动降级
  Future<Map<String, dynamic>> generateJsonResponse(
      String systemPrompt, String userPrompt) async {
    // 尝试主渠道
    final primaryResult = _activeProvider == LlmProvider.qwen
        ? await _generateJsonResponseQwen(systemPrompt, userPrompt)
        : await _generateJsonResponseDoubao(systemPrompt, userPrompt);

    if (!_isFailure(primaryResult)) return primaryResult;

    // 主渠道失败，降级到备用渠道
    if (kDebugMode) {
      debugPrint('[LlmService] ${_activeProvider.name} JSON 请求失败，自动降级到 ${_fallbackProvider.name}');
    }

    final fallbackResult = _fallbackProvider == LlmProvider.qwen
        ? await _generateJsonResponseQwen(systemPrompt, userPrompt)
        : await _generateJsonResponseDoubao(systemPrompt, userPrompt);

    if (fallbackResult['success'] == true) {
      fallbackResult['fallback'] = true;
      fallbackResult['fallback_provider'] = _fallbackProvider.name;
    }
    return fallbackResult;
  }

  // ========================= 千问渠道 =========================

  Future<Map<String, dynamic>> _generateResponseQwen(String prompt) async {
    if (_qwenApiKey == null || _qwenApiKey!.isEmpty) {
      return _errorResult('请配置 QWEN_API_KEY');
    }

    try {
      final body = {
        'model': _qwenModelName ?? 'qwen3.7-plus',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': _maxTokens,
        'temperature': _temperature,
      };

      if (kDebugMode) {
        debugPrint('[Qwen] Request: ${json.encode(body)}');
      }

      final response = await http.post(
        Uri.parse('$_qwenBaseUrl/chat/completions'),
        headers: _qwenHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint('[Qwen] Status: ${response.statusCode}');
        debugPrint('[Qwen] Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final choice = data['choices']?[0];
        final message = choice?['message'];

        final content = (message?['content'] as String?) ?? '收到你的消息！';
        final reasoning = (message?['reasoning_content'] as String?) ?? '根据用户问题进行分析和回答。';

        return {
          'success': true,
          'response': content,
          'reasoning': reasoning,
          'raw_response': data,
        };
      } else {
        return _apiErrorResult(response);
      }
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Future<Map<String, dynamic>> _generateJsonResponseQwen(
      String systemPrompt, String userPrompt) async {
    if (_qwenApiKey == null || _qwenApiKey!.isEmpty) {
      return _errorResult('请配置 QWEN_API_KEY');
    }

    try {
      final body = {
        'model': _qwenModelName ?? 'qwen3.7-plus',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'max_tokens': _maxTokens,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      };

      if (kDebugMode) {
        debugPrint('[Qwen] JSON Request: ${json.encode(body)}');
      }

      final response = await http.post(
        Uri.parse('$_qwenBaseUrl/chat/completions'),
        headers: _qwenHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint('[Qwen] JSON Status: ${response.statusCode}');
        debugPrint('[Qwen] JSON Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final choice = data['choices']?[0];
        final message = choice?['message'];
        String content = (message?['content'] as String?) ?? '{}';

        if (kDebugMode) {
          debugPrint('[Qwen] JSON content: $content');
        }

        return _parseJsonContent(content, data);
      } else {
        return _apiErrorResult(response);
      }
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Map<String, String> _qwenHeaders() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_qwenApiKey',
      };

  // ========================= 豆包渠道 =========================

  Future<Map<String, dynamic>> _generateResponseDoubao(String prompt) async {
    if (_doubaoApiKey == null || _doubaoBaseUrl == null) {
      return _errorResult('请配置 DOUBAO_API_KEY 和 DOUBAO_BASE_URL');
    }

    try {
      final body = {
        'model': _doubaoModelName ?? 'doubao-seed-2-0-lite-260215',
        'input': prompt,
        'thinking': {'type': 'enabled'},
        'stream': false,
      };

      if (kDebugMode) {
        debugPrint('[Doubao] Request: ${json.encode(body)}');
      }

      final response = await http.post(
        Uri.parse('$_doubaoBaseUrl/responses'),
        headers: _doubaoHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint('[Doubao] Status: ${response.statusCode}');
        debugPrint('[Doubao] Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        String content = '';
        String reasoning = '';

        if (data['output'] is List) {
          for (var item in data['output']) {
            if (item['type'] == 'message') {
              if (item['content'] is List && item['content'].isNotEmpty) {
                for (var contentItem in item['content']) {
                  if (contentItem['type'] == 'output_text' &&
                      contentItem['text'] != null) {
                    content = contentItem['text'];
                    break;
                  }
                }
              }
            } else if (item['type'] == 'reasoning') {
              if (item['summary'] is List && item['summary'].isNotEmpty) {
                for (var summaryItem in item['summary']) {
                  if (summaryItem['type'] == 'summary_text' &&
                      summaryItem['text'] != null) {
                    reasoning = summaryItem['text'];
                    break;
                  }
                }
              }
            }
          }
        }

        if (content.isEmpty) content = '收到你的消息！';
        if (reasoning.isEmpty) reasoning = '根据用户问题进行分析和回答。';

        if (kDebugMode) {
          debugPrint('[Doubao] content: $content');
          debugPrint('[Doubao] reasoning: $reasoning');
        }

        return {
          'success': true,
          'response': content,
          'reasoning': reasoning,
          'raw_response': data,
        };
      } else {
        return _apiErrorResult(response);
      }
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Future<Map<String, dynamic>> _generateJsonResponseDoubao(
      String systemPrompt, String userPrompt) async {
    if (_doubaoApiKey == null || _doubaoBaseUrl == null) {
      return _errorResult('请配置 DOUBAO_API_KEY 和 DOUBAO_BASE_URL');
    }

    try {
      final body = {
        'model': _doubaoModelName ?? 'doubao-seed-1-6-251015',
        'thinking': {'type': 'disabled'},
        'text': {
          'format': {'type': 'json_object'},
        },
        'input': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      };

      if (kDebugMode) {
        debugPrint('[Doubao] JSON Request: ${json.encode(body)}');
      }

      final response = await http.post(
        Uri.parse('$_doubaoBaseUrl/responses'),
        headers: _doubaoHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        debugPrint('[Doubao] JSON Status: ${response.statusCode}');
        debugPrint('[Doubao] JSON Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        String content = '';

        if (data['output'] is List) {
          for (var item in data['output']) {
            if (item['type'] == 'message') {
              if (item['content'] is List && item['content'].isNotEmpty) {
                for (var contentItem in item['content']) {
                  if (contentItem['type'] == 'output_text' &&
                      contentItem['text'] != null) {
                    content = contentItem['text'];
                    break;
                  }
                }
              }
            }
          }
        }

        if (content.isEmpty) content = '{}';

        if (kDebugMode) {
          debugPrint('[Doubao] JSON content: $content');
        }

        return _parseJsonContent(content, data);
      } else {
        return _apiErrorResult(response);
      }
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Map<String, String> _doubaoHeaders() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_doubaoApiKey',
      };

  // ========================= 公共工具方法 =========================

  /// 解析 JSON 内容（两个渠道共用）
  Map<String, dynamic> _parseJsonContent(String content, dynamic rawData) {
    try {
      String cleanContent = content.trim();

      // 清理 markdown 代码围栏
      final markdownRegex = RegExp(r'^```(?:json)?\s*([\s\S]*?)```$');
      final markdownMatch = markdownRegex.firstMatch(cleanContent);
      if (markdownMatch != null) {
        cleanContent = markdownMatch.group(1)!.trim();
      } else if (cleanContent.startsWith('```')) {
        cleanContent = cleanContent.substring(3).trim();
        cleanContent = cleanContent.replaceAll(RegExp(r'```$'), '').trim();
      }

      // 直接解析
      final jsonResult = json.decode(cleanContent);
      return {
        'success': true,
        'response': content,
        'json': jsonResult,
        'raw_response': rawData,
      };
    } catch (e) {
      // 回退：正则提取 JSON 对象
      final jsonRegex = RegExp(
          r'\{[\s\S]*"number"\s*:\s*\d+[\s\S]*"category"\s*:\s*"[^"]*"[^\}]*\}');
      final match = jsonRegex.firstMatch(content);
      if (match != null) {
        try {
          final jsonResult = json.decode(match.group(0)!);
          debugPrint('[JSONFallback] Regex extract: $jsonResult');
          return {
            'success': true,
            'response': content,
            'json': jsonResult,
            'raw_response': rawData,
          };
        } catch (_) {}
      }

      // 最终回退：花括号匹配
      var braceCount = 0;
      var startIdx = -1;
      for (var i = 0; i < content.length && startIdx == -1; i++) {
        if (content[i] == '{') startIdx = i;
        if (startIdx != -1) {
          if (content[i] == '{') braceCount++;
          if (content[i] == '}') braceCount--;
          if (braceCount == 0) {
            try {
              final jsonResult =
                  json.decode(content.substring(startIdx, i + 1));
              debugPrint('[JSONFallback] Brace match: $jsonResult');
              return {
                'success': true,
                'response': content,
                'json': jsonResult,
                'raw_response': rawData,
              };
            } catch (_) {}
            break;
          }
        }
      }

      return {
        'success': true,
        'response': content,
        'json': null,
        'reasoning': 'JSON解析失败: $e',
        'raw_response': rawData,
      };
    }
  }

  // ========================= 错误构造 =========================

  Map<String, dynamic> _errorResult(String message) => {
        'success': false,
        'response': message,
        'reasoning': '未配置API密钥',
      };

  Map<String, dynamic> _apiErrorResult(http.Response response) {
    if (kDebugMode) {
      debugPrint('API Error: ${response.statusCode} - ${response.body}');
    }
    return {
      'success': false,
      'response': 'API请求失败: ${response.statusCode}',
      'reasoning': 'API错误',
    };
  }

  Map<String, dynamic> _exceptionResult(dynamic e) {
    if (kDebugMode) {
      debugPrint('Request Error: $e');
    }
    return {
      'success': false,
      'response': '请求出错: $e',
      'reasoning': '网络错误',
    };
  }
}
