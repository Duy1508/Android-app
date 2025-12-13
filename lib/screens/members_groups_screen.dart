import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MembersGroupScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const MembersGroupScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<MembersGroupScreen> createState() => _MembersGroupScreenState();
}

class _MembersGroupScreenState extends State<MembersGroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _addMemberController = TextEditingController();
  Map<String, dynamic>? _groupData;
  Map<String, Map<String, dynamic>> _usersMap = {};
  bool _loading = true;
  List<Map<String, dynamic>> _searchResults = [];
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    setState(() => _loading = true);

    // lấy username của currentUserId
    final userDoc =
    await _firestore.collection('users').doc(widget.currentUserId).get();
    _currentUsername = userDoc.data()?['username'] ?? widget.currentUserId;

    final doc = await _firestore.collection('groups').doc(widget.groupId).get();
    if (doc.exists) {
      final data = doc.data()!;
      final members = (data['members'] as List?)?.cast<String>() ?? [];
      Map<String, Map<String, dynamic>> map = {};
      if (members.isNotEmpty) {
        final snap = await _firestore
            .collection('users')
            .where('username', whereIn: members)
            .get();
        for (final d in snap.docs) {
          final uData = d.data();
          final uname = uData['username'] ?? d.id;
          map[uname] = uData;
        }
      }
      setState(() {
        _groupData = data;
        _usersMap = map;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  bool _isLeader() {
    return _groupData?['leaderId'] == _currentUsername;
  }

  Future<void> _searchUsersByName(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final snap = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    setState(() {
      _searchResults = snap.docs.map((d) {
        final data = d.data();
        return {
          'username': data['username'] ?? d.id,
          'avatarUrl': data['avatarUrl'] ?? '',
        };
      }).toList();
    });
  }

  Future<void> _addMember(String username) async {
    await _firestore.collection('groups').doc(widget.groupId).update({
      'members': FieldValue.arrayUnion([username]),
    });
    _addMemberController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã thêm $username vào nhóm')),
    );
    _loadGroupInfo();
  }

  Future<void> _kickMember(String username) async {
    await _firestore.collection('groups').doc(widget.groupId).update({
      'members': FieldValue.arrayRemove([username]),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã đuổi $username khỏi nhóm')),
    );
    _loadGroupInfo();
  }

  Future<void> _deleteGroup() async {
    await _firestore.collection('groups').doc(widget.groupId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nhóm đã được giải tán')),
    );
    Navigator.pop(context);
  }

  void _confirmKick(String username) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Đuổi "$username" khỏi nhóm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _kickMember(username);
            },
            child: const Text('Đuổi'),
          ),
        ],
      ),
    );
  }

  void _confirmDisband() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Giải tán nhóm'),
        content: const Text('Bạn có chắc muốn giải tán nhóm này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroup();
            },
            child: const Text('Giải tán', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final members = (_groupData?['members'] as List?)?.cast<String>() ?? [];
    final leaderUsername = _groupData?['leaderId'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thành viên nhóm'),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (_isLeader())
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _addMemberController,
                    decoration: const InputDecoration(
                      labelText: 'Tìm thành viên theo username',
                    ),
                    onChanged: _searchUsersByName,
                  ),
                  if (_searchResults.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final s = _searchResults[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: s['avatarUrl'] != ''
                                  ? NetworkImage(s['avatarUrl'])
                                  : null,
                              child: s['avatarUrl'] == ''
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(s['username']),
                            onTap: () => _addMember(s['username']),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: members.isEmpty
                ? const Center(child: Text('Nhóm chưa có thành viên'))
                : ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final username = members[i];
                final userInfo = _usersMap[username] ?? {};
                final displayName = userInfo['username'] ?? username;
                final isLeader = leaderUsername == username;
                final canKick = _isLeader() &&
                    username != leaderUsername &&
                    username != _currentUsername;

                return ListTile(
                  leading: Icon(
                    isLeader ? Icons.star : Icons.person,
                    color: isLeader ? Colors.amber : null,
                  ),
                  title: Text(displayName),
                  subtitle: isLeader ? const Text('Trưởng nhóm') : null,
                  trailing: canKick
                      ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.redAccent),
                    tooltip: 'Đuổi thành viên',
                    onPressed: () => _confirmKick(username),
                  )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isLeader()
          ? Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          icon: const Icon(Icons.delete_forever),
          label: const Text('Giải tán nhóm'),
          onPressed: _confirmDisband,
        ),
      )
          : null,
    );
  }
}
