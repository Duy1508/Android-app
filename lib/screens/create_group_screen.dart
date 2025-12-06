import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateGroupScreen extends StatefulWidget {
  final String currentUserId;
  final String? groupId; // thêm để hỗ trợ chỉnh sửa

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _loadGroupData();
    }
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
        _groupNameController.text = data['name'] ?? '';
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

  void _addMember() {
    final id = _memberController.text.trim();
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
      final ref = widget.groupId != null
          ? FirebaseFirestore.instance.collection('groups').doc(widget.groupId)
          : FirebaseFirestore.instance.collection('groups').doc();

      await ref.set({
        'name': name,
        'members': _members,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'lastMessageReadBy': [],
      }, SetOptions(merge: true));

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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    decoration: const InputDecoration(
                        labelText: 'Thêm thành viên (userId)'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addMember,
                ),
              ],
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
