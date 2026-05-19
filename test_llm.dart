
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  print('=== LLM API 测试 ===\n');
  
  await testBasicChat();
  await testToolCall();
  
  print('\n=== 测试完成 ===');
}

Future<void> testBasicChat() async {
  print('1. 测试基础对话...');
  
  const apiKey = '40188f40-f9a6-479d-adfd-fc06021ad16e';
  const baseUrl = 'https://ark.cn-beijing.volces.com/api/v3';
  
  try {
    final messages = [
      {
        'role': 'system',
        'content': '你是一个语言学习助手，帮助用户学习中文和英文。请用友好、简洁的方式回答问题。',
      },
      {
        'role': 'user',
        'content': 'Hello, how are you?',
      },
    ];

    final body = json.encode({
      'model': 'doubao-seed-2-0-mini-260428',
      'messages': messages,
      'max_tokens': 8192,
      'temperature': 0.7,
      'stream': false,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      final reasoning = data['choices']?[0]?['message']?['reasoning'] ?? 
                        data['thinking'] ?? '无推理内容';
      
      print('   ✅ 成功!');
      print('   Response: $content');
      print('   Reasoning: $reasoning');
    } else {
      print('   ❌ 失败! 状态码: ${response.statusCode}');
      print('   错误信息: ${response.body}');
    }
  } catch (e) {
    print('   ❌ 异常! $e');
  }
}

Future<void> testToolCall() async {
  print('\n2. 测试工具调用...');
  
  const apiKey = '40188f40-f9a6-479d-adfd-fc06021ad16e';
  const baseUrl = 'https://ark.cn-beijing.volces.com/api/v3';
  
  try {
    final tools = [
      {
        'type': 'function',
        'function': {
          'name': 'get_weather',
          'description': '获取指定城市的天气信息',
          'parameters': {
            'type': 'object',
            'properties': {
              'city': {
                'type': 'string',
                'description': '城市名称',
              },
            },
            'required': ['city'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'query_dictionary',
          'description': '查询字词释义、成语解释',
          'parameters': {
            'type': 'object',
            'properties': {
              'word': {
                'type': 'string',
                'description': '要查询的字词或成语',
              },
            },
            'required': ['word'],
          },
        },
      },
    ];

    final messages = [
      {
        'role': 'system',
        'content': '你是一个语言学习助手。',
      },
      {
        'role': 'user',
        'content': '"杯龙明珠"是什么意思？',
      },
    ];

    final body = json.encode({
      'model': 'doubao-seed-2-0-mini-260428',
      'messages': messages,
      'tools': tools,
      'tool_choice': 'auto',
      'max_tokens': 8192,
      'temperature': 0.7,
      'stream': false,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      final toolCalls = data['choices']?[0]?['message']?['tool_calls'];
      
      print('   ✅ 成功!');
      print('   Response: $content');
      print('   需要工具调用: ${toolCalls != null && toolCalls.isNotEmpty}');
      if (toolCalls != null && toolCalls.isNotEmpty) {
        print('   工具调用详情: $toolCalls');
      }
    } else {
      print('   ❌ 失败! 状态码: ${response.statusCode}');
      print('   错误信息: ${response.body}');
    }
  } catch (e) {
    print('   ❌ 异常! $e');
  }
}
