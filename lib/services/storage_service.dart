import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

import "package:ccviewer_mobile_hub/models/saved_connection.dart";

/// 存储服务 - 使用 shared_preferences 持久化连接信息
class StorageService {
  StorageService();

  static const String _storageKey = "saved_connections";

  SharedPreferences? _prefs;

  /// 获取 SharedPreferences 实例
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 加载所有已保存连接
  Future<List<SavedConnection>> loadConnections() async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return <SavedConnection>[];
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        return <SavedConnection>[];
      }

      final connections = <SavedConnection>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          connections.add(SavedConnection.fromJson(item));
        } else if (item is Map) {
          connections.add(SavedConnection.fromJson(item.cast<String, dynamic>()));
        }
      }
      return connections;
    } catch (e) {
      // 解析失败时返回空列表
      return <SavedConnection>[];
    }
  }

  /// 保存/更新连接（按 id 去重）
  Future<void> saveConnection(SavedConnection conn) async {
    final connections = await loadConnections();

    // 查找是否存在相同 id 的连接
    final existingIndex = connections.indexWhere((c) => c.id == conn.id);

    if (existingIndex >= 0) {
      // 更新已存在的连接
      connections[existingIndex] = conn;
    } else {
      // 添加新连接
      connections.add(conn);
    }

    await _saveConnectionsToStorage(connections);
  }

  /// 删除连接
  Future<void> deleteConnection(String id) async {
    final connections = await loadConnections();
    connections.removeWhere((c) => c.id == id);
    await _saveConnectionsToStorage(connections);
  }

  /// 更新别名
  Future<void> updateAlias(String id, String alias) async {
    final connections = await loadConnections();
    final index = connections.indexWhere((c) => c.id == id);

    if (index >= 0) {
      connections[index].alias = alias;
      await _saveConnectionsToStorage(connections);
    }
  }

  /// 更新连接状态
  Future<void> updateConnectionStatus(String id, String status) async {
    final connections = await loadConnections();
    final index = connections.indexWhere((c) => c.id == id);

    if (index >= 0) {
      connections[index].lastStatus = status;
      connections[index].lastConnectedAt = DateTime.now();
      await _saveConnectionsToStorage(connections);
    }
  }

  /// 将连接列表保存到存储
  Future<void> _saveConnectionsToStorage(List<SavedConnection> connections) async {
    final prefs = await _getPrefs();
    final jsonList = connections.map((c) => c.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }

  /// 清除所有保存的连接
  Future<void> clearAllConnections() async {
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }

  /// 批量保存连接列表（替换整个列表）
  Future<void> saveConnections(List<SavedConnection> connections) async {
    await _saveConnectionsToStorage(connections);
  }

  /// 根据 ID 获取连接
  Future<SavedConnection?> getConnectionById(String id) async {
    final connections = await loadConnections();
    try {
      return connections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 根据项目路径查找连接
  Future<SavedConnection?> findConnectionByWorkspacePath(String workspacePath) async {
    final connections = await loadConnections();
    try {
      return connections.firstWhere((c) => c.workspacePath == workspacePath);
    } catch (_) {
      return null;
    }
  }
}
