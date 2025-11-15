import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


  @override
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        builder: (context, snapshot) {


            itemBuilder: (context, index) {

                },
              );
            },
          );
        },
      ),
    );
  }
}
