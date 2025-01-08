import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transparent_image/transparent_image.dart';

class PrayerListManagerScreen extends StatefulWidget {
  @override
  _PrayerListManagerScreenState createState() => _PrayerListManagerScreenState();
}

class _PrayerListManagerScreenState extends State<PrayerListManagerScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isUploading = false;
  String? currentImageUrl;

  Future<String?> _getLatestImageUrl() async {
  try {
    // prayer_lists 폴더의 모든 아이템 가져오기
    final ListResult result = await _storage.ref('prayer_lists').listAll();
    
    if (result.items.isEmpty) {
      print('No images found in storage');
      return null;
    }

    // 가장 최근 파일 가져오기 (파일명이 timestamp이므로 정렬 후 마지막 항목)
    final latest = result.items.last;
    final url = await latest.getDownloadURL();
    print('Latest image URL: $url'); // URL 확인용 로그
    return url;
  } catch (e) {
    print('Error fetching image URL: $e');
    return null;
  }
}

// 이미지 표시 위젯
Widget _buildImageDisplay() {
  return FutureBuilder<String?>(
    future: _getLatestImageUrl(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError || !snapshot.hasData) {
        print('Image loading error: ${snapshot.error}');
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text('이미지를 불러오는데 실패했습니다'),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {}); // 화면 새로고침
                },
                child: Text('다시 시도'),
              ),
            ],
          ),
        );
      }

      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    iconTheme: IconThemeData(color: Colors.white),
                  ),
                  backgroundColor: Colors.black,
                  body: Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: FadeInImage.memoryNetwork(
                        placeholder: kTransparentImage,  // transparentImage import 필요
                        image: snapshot.data!,
                        fit: BoxFit.contain,
                        imageErrorBuilder: (context, error, stackTrace) {
                          print('Error details: $error');
                          return Center(
                            child: Text('이미지 로드 실패', style: TextStyle(color: Colors.white)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: FadeInImage.memoryNetwork(
            placeholder: kTransparentImage,
            image: snapshot.data!,
            fit: BoxFit.contain,
            imageErrorBuilder: (context, error, stackTrace) {
              print('Error details: $error');
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(height: 8),
                    Text('이미지를 불러올 수 없습니다'),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

  @override
  void initState() {
    super.initState();
    _loadCurrentImage();
  }

  Future<void> _loadCurrentImage() async {
    try {
      final doc = await _firestore.collection('settings').doc('prayer_list').get();
      if (doc.exists) {
        setState(() {
          currentImageUrl = doc.data()?['imageUrl'];
        });
      }
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  Future<void> _uploadImage() async {
    try {
      setState(() {
        isUploading = true;
      });

      // 이미지 선택
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
      );

      if (image == null) {
        setState(() {
          isUploading = false;
        });
        return;
      }

      // 이미지 데이터 읽기
      final imageBytes = await image.readAsBytes();
      
      // Storage에 업로드
      final fileName = 'prayer_list_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('prayer_lists/$fileName');
      
      // 메타데이터 설정
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'picked-file-path': image.path}
      );

      // 업로드 실행
      await ref.putData(imageBytes, metadata);
      
      // URL 가져오기
      final downloadUrl = await ref.getDownloadURL();

      // Firestore에 저장
      await _firestore.collection('settings').doc('prayer_list').set({
        'imageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        currentImageUrl = downloadUrl;
        isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기도부탁 명단이 업데이트되었습니다'))
      );

    } catch (e) {
      print('Upload error: $e');
      setState(() {
        isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업로드 실패: 다시 시도해주세요'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('기도부탁 명단'),
    ),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기도부탁 명단',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildImageDisplay(),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isUploading ? null : _uploadImage,
            icon: Icon(Icons.upload_file),
            label: Text(isUploading ? '업로드 중...' : '새 명단 업로드'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    ),
  );
}
}