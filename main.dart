import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

/* ---------------- CONFIG ---------------- */

const String BACKEND_BASE = "https://chatallama.tech";
const String CHATS_BOX = "chats_box";

/* ---------------- MAIN ---------------- */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(CHATS_BOX);
  runApp(const MyApp());
}

/* ---------------- APP ---------------- */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Chat-Llama",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const Splash(),
    );
  }
}

/* ---------------- SPLASH ---------------- */

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    await Future.delayed(const Duration(seconds: 1));

    if (token != null) {
      go(const ChatHome());
    } else {
      go(const Login());
    }
  }

  void go(Widget w) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => w),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/* ---------------- LOGIN ---------------- */

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final user = TextEditingController();
  final pass = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

    try {
      print("🔐 LOGIN ATTEMPT");
      print("📍 URL: $BACKEND_BASE/login");
      print("👤 Username: ${user.text}");

      final res = await http.post(
        Uri.parse("$BACKEND_BASE/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": user.text,
          "password": pass.text,
        }),
      ).timeout(const Duration(seconds: 30));

      print("📥 Response Status: ${res.statusCode}");
      print("📥 Response Body: ${res.body}");

      setState(() => loading = false);

      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          print("✅ Login successful");
          if (data != null && data.containsKey("token")) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString("token", data["token"]);
            print("💾 Token saved");
            go(const ChatHome());
          } else {
            msg("❌ No token in response");
          }
        } catch (e) {
          msg("❌ Error processing login: $e");
          print("❌ Parse error: $e");
        }
      } else {
        msg("❌ Login failed: ${res.statusCode}");
        print("❌ Login error status: ${res.statusCode}");
      }
    } on TimeoutException catch (_) {
      setState(() => loading = false);
      msg("❌ Login timeout - Backend not responding");
      print("❌ Timeout exception");
    } catch (e) {
      setState(() => loading = false);
      msg("❌ Connection error: $e");
      print("❌ Connection error: $e");
    }
  }

  void go(Widget w) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => w),
    );
  }

  void msg(String s) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: user,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: loading ? null : login,
              child:
                  loading ? const CircularProgressIndicator() : const Text("Login"),
            ),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Register()),
                );
              },
              child: const Text("Create Account"),
            )
          ],
        ),
      ),
    );
  }
}

/* ---------------- REGISTER ---------------- */

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final user = TextEditingController();
  final pass = TextEditingController();

  bool loading = false;

  Future<void> register() async {
    setState(() => loading = true);

    try {
      print("📝 REGISTRATION ATTEMPT");
      print("📍 URL: $BACKEND_BASE/register");
      print("👤 Username: ${user.text}");

      final res = await http.post(
        Uri.parse("$BACKEND_BASE/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": user.text,
          "password": pass.text,
        }),
      ).timeout(const Duration(seconds: 30));

      print("📥 Response Status: ${res.statusCode}");
      print("📥 Response Body: ${res.body}");

      setState(() => loading = false);

      if (res.statusCode == 200) {
        msg("✅ Account created! Login now");
        print("✅ Registration successful");
        Navigator.pop(context);
      } else {
        msg("❌ Register failed: ${res.statusCode}");
        print("❌ Registration error status: ${res.statusCode}");
      }
    } on TimeoutException catch (_) {
      setState(() => loading = false);
      msg("❌ Registration timeout - Backend not responding");
      print("❌ Timeout exception");
    } catch (e) {
      setState(() => loading = false);
      msg("❌ Connection error: $e");
      print("❌ Connection error: $e");
    }
  }

  void msg(String s) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: user,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- MODELS ---------------- */

class Message {
  String text;
  bool isUser;

  Message(this.text, this.isUser);

  // Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    "text": text,
    "isUser": isUser,
  };

  // Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    json["text"] as String,
    json["isUser"] as bool,
  );
}

class ChatSession {
  String id;
  String title;
  List<Message> messages;
  DateTime createdAt;
  DateTime lastModified;

  ChatSession(
    this.id,
    this.title,
    this.messages, {
    DateTime? createdAt,
    DateTime? lastModified,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  // Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "messages": messages.map((m) => m.toJson()).toList(),
    "createdAt": createdAt.toIso8601String(),
    "lastModified": lastModified.toIso8601String(),
  };

  // Create from JSON
  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    json["id"] as String,
    json["title"] as String,
    (json["messages"] as List)
        .map((m) => Message.fromJson(m as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json["createdAt"] as String),
    lastModified: DateTime.parse(json["lastModified"] as String),
  );
}

/* ---------------- CHAT ---------------- */

class ChatHome extends StatefulWidget {
  const ChatHome({super.key});

  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  final controller = TextEditingController();
  final scroll = ScrollController();

  final List<ChatSession> sessions = [];

  ChatSession? current;

  bool typing = false;
  bool autoScroll = true;

  String? token;
  Timer? streamTimer;
  late Box chatsBox;

/* ---------------- INIT ---------------- */

  @override
  void initState() {
    super.initState();

    scroll.addListener(() {
      if (!scroll.hasClients) return;

      final max = scroll.position.maxScrollExtent;
      final pos = scroll.offset;

      autoScroll = (max - pos) < 150;
    });

    load();
  }

  @override
  void dispose() {
    streamTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");

    chatsBox = Hive.box(CHATS_BOX);

    // Load all chats from Hive
    loadChatsFromStorage();

    // If no chats exist, create new one
    if (sessions.isEmpty) {
      createChat();
    } else {
      current = sessions.first;
    }

    setState(() {});
  }

/* ---------------- STORAGE FUNCTIONS ----------------  */

  void loadChatsFromStorage() {
    sessions.clear();

    final chatsData = chatsBox.keys;

    for (var key in chatsData) {
      try {
        final jsonStr = chatsBox.get(key) as String;
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final chat = ChatSession.fromJson(json);
        sessions.add(chat);
      } catch (e) {
        print("Error loading chat: $e");
      }
    }

    // Sort by last modified (newest first)
    sessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));
  }

  Future<void> saveChatToStorage(ChatSession chat) async {
    chat.lastModified = DateTime.now();
    await chatsBox.put(chat.id, jsonEncode(chat.toJson()));
  }

  Future<void> deleteChatsFromStorage(String chatId) async {
    await chatsBox.delete(chatId);
  }

/* ---------------- TITLE ---------------- */

  String generateTitle(String text) {
    text = text.trim();

    if (text.length <= 25) return text;

    return "${text.substring(0, 25)}...";
  }

/* ---------------- CHAT CONTROL ---------------- */

  void createChat() {
    final chat = ChatSession(
      DateTime.now().millisecondsSinceEpoch.toString(),
      "New Chat",
      [],
    );

    sessions.insert(0, chat);
    current = chat;
    saveChatToStorage(chat);

    setState(() {});
  }

  void deleteChat(ChatSession s) {
    sessions.remove(s);
    deleteChatsFromStorage(s.id);

    if (sessions.isEmpty) {
      createChat();
    } else if (current?.id == s.id) {
      current = sessions.first;
    }

    setState(() {});
    Navigator.pop(context);
  }

/* ---------------- MSG ---------------- */

  void msg(String s) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s)));
  }

/* ---------------- SEND ---------------- */

  Future<void> send() async {
    final text = controller.text.trim();

    if (text.isEmpty || current == null) return;

    controller.clear();

    // Auto title
    if (current!.messages.isEmpty) {
      current!.title = generateTitle(text);
    }

    setState(() {
      current!.messages.add(Message(text, true));
      typing = true;
    });

    await saveChatToStorage(current!);
    scrollDown();

    try {
      print("📤 Sending message: '$text'");
      print("🔑 Token: $token");
      print("🌐 Backend URL: $BACKEND_BASE/chat");

      final res = await http.post(
        Uri.parse("$BACKEND_BASE/chat"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"message": text}),
      ).timeout(const Duration(seconds: 30));

      print("📥 Response Status: ${res.statusCode}");
      print("📥 Response Body: ${res.body}");

      typing = false;

      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          if (data != null && data.containsKey("reply")) {
            stream(data["reply"]);
          } else if (data != null && data.containsKey("error")) {
            msg("❌ Backend error: ${data['error']}");
          } else {
            msg("❌ Invalid response - no reply field");
          }
        } catch (e) {
          msg("❌ Parse error: Check console");
        }
      } else if (res.statusCode == 502) {
        msg("❌ 502: Backend is down or not accessible");
      } else if (res.statusCode == 401) {
        msg("❌ 401: Token expired - Login again");
        logout();
      } else if (res.statusCode == 500) {
        msg("❌ 500: Server error on backend");
      } else {
        msg("❌ HTTP ${res.statusCode}");
      }

      setState(() {});
    } on TimeoutException catch (_) {
      typing = false;
      msg("❌ Request timeout - Backend not responding");
      setState(() {});
    } catch (e) {
      typing = false;
      print("❌ Exception: $e");
      msg("❌ Connection failed");
      setState(() {});
    }
  }

/* ---------------- STREAM - FULLY SCROLLABLE WHILE TYPING ---------------- */

  Future<void> stream(String full) async {
    final msg = Message("", false);
    current!.messages.add(msg);

    int i = 0;
    const batchSize = 50;  // Large batches
    const updateInterval = 50;  // Fast updates for responsiveness

    streamTimer?.cancel();
    
    streamTimer = Timer.periodic(Duration(milliseconds: updateInterval), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (i >= full.length) {
        t.cancel();
        if (mounted) {
          setState(() {});
          // Save to storage when done
          saveChatToStorage(current!);
          // Auto scroll to bottom when done
          Future.delayed(Duration(milliseconds: 100), scrollDown);
        }
        return;
      }

      // Add large chunk of text
      int charactersAdded = 0;
      while (charactersAdded < batchSize && i < full.length) {
        msg.text += full[i];
        i++;
        charactersAdded++;
      }

      // Minimal setState
      if (mounted) {
        setState(() {});
      }
    });
  }

/* ---------------- SCROLL ---------------- */

  void scrollDown() {
    if (!autoScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;

      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

/* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(),
      appBar: AppBar(
        title: const Text("Chat-Llama 🦙"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: createChat,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: Column(
        children: [
          buildChat(),
          buildInput(),
        ],
      ),
    );
  }

/* ---------------- LOGOUT ---------------- */

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
    );
  }

/* ---------------- DRAWER - CHATGPT STYLE SIDEBAR ----------------  */

  Widget buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Chat-Llama 🦙",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: createChat,
                  icon: const Icon(Icons.add),
                  label: const Text("New Chat"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Chat List
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      "No chats yet",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final isSelected = current?.id == s.id;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            "${s.messages.length} messages",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          onTap: () {
                            current = s;
                            Navigator.pop(context);
                            setState(() {});
                          },
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text("Delete"),
                                  ],
                                ),
                                onTap: () => deleteChat(s),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Logout"),
                  onTap: logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

/* ---------------- CHAT VIEW - FULL CONVERSATION HISTORY ----------------  */

  Widget buildChat() {
    if (current == null) return const SizedBox();

    return Expanded(
      child: current!.messages.isEmpty
          ? Center(
              child: Text(
                "Start a conversation",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(12),
              itemCount: current!.messages.length + (typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (typing && i == current!.messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 10),
                        Text("AI is thinking..."),
                      ],
                    ),
                  );
                }

                final msg = current!.messages[i];

                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      gradient: msg.isUser
                          ? const LinearGradient(
                              colors: [Colors.blue, Colors.purple],
                            )
                          : null,
                      color: msg.isUser ? null : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(blurRadius: 5, color: Colors.black12),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

/* ---------------- INPUT ---------------- */

  Widget buildInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(blurRadius: 6, color: Colors.black12),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Ask Chat-Llama...",
                  border: InputBorder.none,
                ),
              ),
            ),

            CircleAvatar(
              backgroundColor: Colors.blue,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
