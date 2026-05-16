import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  // 硬编码配置，避免 .env 文件依赖问题
  static const String _defaultApiKey = '40188f40-f9a6-479d-adfd-fc06021ad16e';
  static const String _defaultBaseUrl = 'https://ark.cn-beijing.volces.com/api/v3';
  static const String _defaultModelName = 'doubao-seed-2-0-mini-260428';
  static const int _defaultMaxTokens = 256000;
  static const double _defaultTemperature = 0.7;

  String? _apiKey;
  String? _baseUrl;
  String? _modelName;

  Future<void> init() async {
    // 直接使用硬编码配置，不再依赖 .env 文件
    _apiKey = _defaultApiKey;
    _baseUrl = _defaultBaseUrl;
    _modelName = _defaultModelName;
  }

  Future<Map<String, dynamic>> generateResponse(String prompt) async {
    if (_apiKey == null || _baseUrl == null) {
      return {
        'success': false,
        'response': '请配置API_KEY和BASE_URL',
        'reasoning': '未配置API密钥',
      };
    }

    try {
      final body = {
        'model': _modelName ?? 'doubao-seed-2-0-lite-260215',
        'input': prompt,
        'thinking': {'type': 'enabled'},
        'stream': false,
      };

      if (kDebugMode) {
        debugPrint('Request Body: ${json.encode(body)}');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/responses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(body),
      );

      if (kDebugMode) {
        debugPrint('API Status: ${response.statusCode}');
        debugPrint('API Response Body: ${response.body}');
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
                  if (contentItem['type'] == 'output_text' && contentItem['text'] != null) {
                    content = contentItem['text'];
                    break;
                  }
                }
              }
            } else if (item['type'] == 'reasoning') {
              if (item['summary'] is List && item['summary'].isNotEmpty) {
                for (var summaryItem in item['summary']) {
                  if (summaryItem['type'] == 'summary_text' && summaryItem['text'] != null) {
                    reasoning = summaryItem['text'];
                    break;
                  }
                }
              }
            }
          }
        }

        if (content.isEmpty) {
          content = '收到你的消息！';
        }

        if (reasoning.isEmpty) {
          reasoning = '根据用户问题进行分析和回答。';
        }

        if (kDebugMode) {
          debugPrint('Extracted content: $content');
          debugPrint('Extracted reasoning: $reasoning');
        }

        return {
          'success': true,
          'response': content,
          'reasoning': reasoning,
          'raw_response': data,
        };
      } else {
        if (kDebugMode) {
          debugPrint('API Error: ${response.statusCode} - ${response.body}');
        }
        return {
          'success': false,
          'response': 'API请求失败: ${response.statusCode}',
          'reasoning': 'API错误',
        };
      }
    } catch (e) {
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

  Future<Map<String, dynamic>> generateResponseWithTools(
    String prompt, {
    List<Map<String, dynamic>>? tools,
    bool toolChoice = false,
  }) async {
    return await generateResponse(prompt);
  }

  Future<Map<String, dynamic>> testToolCall(String prompt) async {
    return await generateResponse(prompt);
  }

  Future<Map<String, dynamic>> generateJsonResponse(String systemPrompt, String userPrompt) async {
    if (_apiKey == null || _baseUrl == null) {
      return {
        'success': false,
        'response': '请配置API_KEY和BASE_URL',
        'reasoning': '未配置API密钥',
      };
    }

    try {
      final body = {
        'model': _modelName ?? 'doubao-seed-1-6-251015',
        'thinking': {'type': 'disabled'},
        'text': {
          'format': {
            'type': 'json_object',
          },
        },
        'input': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': userPrompt,
          },
        ],
      };

      if (kDebugMode) {
        debugPrint('JSON Request Body: ${json.encode(body)}');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/responses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode(body),
      );

      if (kDebugMode) {
        debugPrint('API Status: ${response.statusCode}');
        debugPrint('API Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        String content = '';

        if (data['output'] is List) {
          for (var item in data['output']) {
            if (item['type'] == 'message') {
              if (item['content'] is List && item['content'].isNotEmpty) {
                for (var contentItem in item['content']) {
                  if (contentItem['type'] == 'output_text' && contentItem['text'] != null) {
                    content = contentItem['text'];
                    break;
                  }
                }
              }
            }
          }
        }

        if (content.isEmpty) {
          content = '{}';
        }

        if (kDebugMode) {
          debugPrint('Extracted JSON content: $content');
        }

        try {
          final jsonResult = json.decode(content);
          return {
            'success': true,
            'response': content,
            'json': jsonResult,
            'raw_response': data,
          };
        } catch (e) {
          return {
            'success': true,
            'response': content,
            'json': null,
            'reasoning': 'JSON解析失败: $e',
            'raw_response': data,
          };
        }
      } else {
        if (kDebugMode) {
          debugPrint('API Error: ${response.statusCode} - ${response.body}');
        }
        return {
          'success': false,
          'response': 'API请求失败: ${response.statusCode}',
          'reasoning': 'API错误',
        };
      }
    } catch (e) {
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
}
