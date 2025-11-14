import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart'; // 👈 nhớ import màn hình xem profile

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> searchResults = [];

  void _searchUser(String query) async {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    final nameQuery = FirebaseFirestore.instance
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    final emailQuery = FirebaseFirestore.instance
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    final results = await Future.wait([nameQuery, emailQuery]);

    final allDocs = [...results[0].docs, ...results[1].docs];
    final uniqueDocs = {
      for (var doc in allDocs) doc.id: doc,
    }.values.toList();

    setState(() => searchResults = uniqueDocs);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _searchUser,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final doc = searchResults[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Không rõ';
              final email = data['email'] ?? '';
              final avatarUrl = data['avatarUrl'];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: avatarUrl != null && avatarUrl != ''
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl == ''
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(name),
                subtitle: Text(email),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: doc.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
