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
  List<Map<String, dynamic>> _suggestions = []; // gợi ý từ following
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _loadGroupData();
    }
    _loadFollowings();
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

  Future<void> _loadFollowings() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('following')
          .get();

      final ids = snap.docs.map((d) => d.id).toList();

      if (ids.isNotEmpty) {
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: ids)
            .get();

        setState(() {
          _suggestions = usersSnap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'name': data['name'] ?? d.id,
              'avatarUrl': data['avatarUrl'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Lỗi load followings: $e');
    }
  }

  void _addMember(String id) {
    if (id.isNotEmpty && !_members.contains(id)) {
      setState(() {
        _members.add(id);
      });
      _memberController.clear();
    }
  }

  void _removeMember(String id) {
    setState(() {
      _members.remove(id);
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

    if (!_members.contains(widget.currentUserId)) {
      _members.add(widget.currentUserId);
    }

    setState(() => _isLoading = true);

    try {
      final groups = FirebaseFirestore.instance.collection('groups');
      final docRef = widget.groupId != null
          ? groups.doc(widget.groupId)
          : groups.doc();

      String leaderId = widget.currentUserId;
      if (widget.groupId != null) {
        final existing = await docRef.get();
        leaderId =
            (existing.data()?['leaderId'] as String?) ?? widget.currentUserId;
      }

      final baseData = <String, dynamic>{
        'name': name,
        'members': _members,
        'leaderId': leaderId,
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
        .where((s) => (s['name'] as String).toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa nhóm' : 'Tạo nhóm mới'),
      ),
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
                labelText: 'Thêm thành viên (userId hoặc tên)',
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
                      title: Text(s['name']),
                      subtitle: Text(s['id']),
                      onTap: () => _addMember(s['id']),
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
              child: Text(isEditing ? 'Lưu thay đổi' : 'Tạo nhóm'),
            ),
          ],
        ),
      ),
    );
  }
}