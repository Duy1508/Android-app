import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateGroupScreen extends StatefulWidget {
  final String currentUserId;
  final String? groupId; // nếu null: tạo mới, nếu có: chỉnh sửa

  const CreateGroupScreen({
    super.key,
    required this.currentUserId,
    this.groupId,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _members = [];
  List<Map<String, dynamic>> _suggestions = []; // gợi ý từ users
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _loadGroupData();
    }
    _loadUsers(); // lấy danh sách users để gợi ý
  }

  Future<void> _loadGroupData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _groupNameController.text = (data['name'] as String?) ?? '';
        final loadedMembers = (data['members'] as List?)?.cast<String>() ?? [];
        setState(() => _members.addAll(loadedMembers));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải nhóm: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Lấy danh sách tất cả users để gợi ý (dùng username)
  Future<void> _loadUsers() async {
    try {
      final usersSnap =
      await FirebaseFirestore.instance.collection('users').get();

      setState(() {
        _suggestions = usersSnap.docs.map((d) {
          final data = d.data();
          return {
            'id': d.id, //
            'username': data['username'] ?? d.id,
            'avatarUrl': data['avatarUrl'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Lỗi load users: $e');
    }
  }

  void _addMember(String username) {
    if (username.isNotEmpty && !_members.contains(username)) {
      setState(() {
        _members.add(username);
      });
      _memberController.clear();
    }
  }

  void _removeMember(String username) {
    setState(() {
      _members.remove(username);
    });
  }

  Future<void> _saveGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên nhóm')),
      );
      return;
    }

    // lấy username của currentUser
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .get();
    final currentUsername =
        currentUserDoc.data()?['username'] ?? widget.currentUserId;

    if (!_members.contains(currentUsername)) {
      _members.add(currentUsername);
    }

    setState(() => _isLoading = true);

    try {
      final groups = FirebaseFirestore.instance.collection('groups');
      final docRef = widget.groupId != null
          ? groups.doc(widget.groupId)
          : groups.doc();

      String leaderUsername = currentUsername;
      if (widget.groupId != null) {
        final existing = await docRef.get();
        leaderUsername =
            (existing.data()?['leaderId'] as String?) ?? currentUsername;
      }

      final baseData = <String, dynamic>{
        'name': name,
        'members': _members, // lưu danh sách username
        'leaderId': leaderUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.groupId == null) {
        baseData.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'lastMessageReadBy': <String>[],
        });
      }

      await docRef.set(baseData, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.groupId != null
              ? 'Cập nhật nhóm thành công'
              : 'Tạo nhóm thành công'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu nhóm: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.groupId != null;

    final query = _memberController.text.trim().toLowerCase();
    final filteredSuggestions = query.isEmpty
        ? _suggestions
        : _suggestions
        .where((s) => (s['username'] as String).toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa nhóm' : 'Tạo nhóm mới'),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(labelText: 'Tên nhóm'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memberController,
              decoration: const InputDecoration(
                labelText: 'Thêm thành viên (username)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (filteredSuggestions.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: filteredSuggestions.length,
                  itemBuilder: (context, i) {
                    final s = filteredSuggestions[i];
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
            const SizedBox(height: 16),
            Expanded(
              child: _members.isEmpty
                  ? const Center(child: Text('Chưa có thành viên'))
                  : ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(_members[i]),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeMember(_members[i]),
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _saveGroup,
              child: Text(
                  isEditing ? 'Lưu thay đổi' : 'Tạo nhóm',
                  style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
