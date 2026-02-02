import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent/llm_agent.dart';

const String _keyAgents = 'llm_agents';
const String _keyDefaultAgentId = 'llm_default_agent_id';

/// Agent 管理模块：增删改查、默认 Agent
/// 需在 [SettingsService.init] 之后使用（依赖 SharedPreferences）
class AgentStorage {
  AgentStorage._();

  static late SharedPreferences _prefs;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  static List<LlmAgent> getAll() {
    final jsonStr = _prefs.getString(_keyAgents);
    if (jsonStr == null || jsonStr.isEmpty) return _defaultAgents();
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final agents = list
          .map((e) => LlmAgent.fromJson(e as Map<String, dynamic>))
          .toList();
      if (agents.isEmpty) return _defaultAgents();
      agents.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return agents;
    } catch (_) {
      return _defaultAgents();
    }
  }

  static LlmAgent? getById(String id) {
    for (final a in getAll()) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 当前默认 Agent，若无则返回第一个
  static LlmAgent? getDefault() {
    final id = _prefs.getString(_keyDefaultAgentId);
    if (id != null) {
      final a = getById(id);
      if (a != null) return a;
    }
    final all = getAll();
    return all.isNotEmpty ? all.first : null;
  }

  static Future<void> setDefault(String? agentId) async {
    if (agentId == null) {
      await _prefs.remove(_keyDefaultAgentId);
    } else {
      await _prefs.setString(_keyDefaultAgentId, agentId);
    }
  }

  static Future<void> save(LlmAgent agent) async {
    final all = getAll();
    final idx = all.indexWhere((a) => a.id == agent.id);
    if (idx >= 0) {
      all[idx] = agent;
    } else {
      all.add(agent);
    }
    await _persist(all);
  }

  /// 生成新 Agent 的唯一 ID
  static String generateId() =>
      'agent_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';

  static Future<void> delete(String id) async {
    final all = getAll().where((a) => a.id != id).toList();
    await _persist(all);
    if (_prefs.getString(_keyDefaultAgentId) == id) {
      await _prefs.remove(_keyDefaultAgentId);
    }
  }

  static Future<void> _persist(List<LlmAgent> agents) async {
    final list = agents.map((a) => a.toJson()).toList();
    await _prefs.setString(_keyAgents, jsonEncode(list));
  }

  static List<LlmAgent> _defaultAgents() {
    return [
      LlmAgent(
        id: 'default',
        name: '通用助手',
        systemPrompt: '你是一个有帮助的助手，简洁、准确地回答用户问题。',
        createdAt: DateTime(2020, 1, 1),
      ),
    ];
  }
}
