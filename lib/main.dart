import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AllumniApp());
}

/// Serviço de Banco de Dados Remoto (Cloud Firestore)
class FirebaseDb {
  static final _db = FirebaseFirestore.instance;

  // Autenticação e Usuários
  static Map<String, dynamic> _cleanUser(String id, Map<String, dynamic> data) {
    final result = <String, dynamic>{'id': id};
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    final query = await _db
        .collection('usuarios')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('E-mail não cadastrado. Clique em "Criar minha conta".');
    }

    final doc = query.docs.first;
    final data = doc.data();
    final savedPassword = (data['senha'] ?? '').toString().trim();
    if (savedPassword.isNotEmpty && savedPassword != cleanPassword) {
      throw Exception('Senha incorreta. Verifique a senha digitada.');
    }

    return _cleanUser(doc.id, data);
  }

  static Future<Map<String, dynamic>> cadastro({
    required String nome,
    required String email,
    required String senha,
    required String curso,
    int? anoFormatura,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final query = await _db
        .collection('usuarios')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception('Este e-mail já está cadastrado. Alterne para "Já tenho uma conta".');
    }

    final docRef = await _db.collection('usuarios').add({
      'nome': nome.trim(),
      'email': cleanEmail,
      'senha': senha.trim(),
      'curso': curso.trim(),
      'ano_formatura': anoFormatura,
      'bio': 'Ex-aluno UNISANTOS.',
      'criado_em': FieldValue.serverTimestamp(),
    });

    final snap = await docRef.get();
    return _cleanUser(docRef.id, snap.data() ?? {});
  }

  // Eventos
  static Stream<List<Map<String, dynamic>>> streamEventos() {
    return _db.collection('eventos').snapshots().map(
      (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }

  // Vagas
  static Stream<List<Map<String, dynamic>>> streamVagas() {
    return _db.collection('vagas').snapshots().map(
      (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }

  static Future<void> candidatarVaga(String vagaId, Map<String, dynamic> user) async {
    await _db.collection('candidaturas').add({
      'vaga_id': vagaId,
      'usuario_id': user['id'] ?? '',
      'usuario_nome': user['nome'] ?? '',
      'usuario_email': user['email'] ?? '',
      'mensagem': 'Candidatura enviada pelo app Allumni.',
      'data': FieldValue.serverTimestamp(),
    });
  }

  // Grupos
  static Stream<List<Map<String, dynamic>>> streamGrupos() {
    return _db.collection('grupos').snapshots().map(
      (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    );
  }

  static Future<void> entrarGrupo(String grupoId, String usuarioId) async {
    await _db.collection('grupos').doc(grupoId).update({
      'membros': FieldValue.arrayUnion([usuarioId]),
    });
  }

  // Perfil
  static Future<Map<String, dynamic>> getPerfil(String usuarioId) async {
    final doc = await _db.collection('usuarios').doc(usuarioId).get();
    if (!doc.exists) return {};
    return doc.data() ?? {};
  }

  static Future<void> updatePerfil(String usuarioId, {
    required String nome,
    required String curso,
    required String bio,
  }) async {
    await _db.collection('usuarios').doc(usuarioId).set({
      'nome': nome.trim(),
      'curso': curso.trim(),
      'bio': bio.trim(),
      'atualizado_em': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class Session {
  static const _key = 'allumni_session';
  static Future<Map<String, dynamic>?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null ? null : Map<String, dynamic>.from(jsonDecode(value));
  }

  static Future<void> save(Map<String, dynamic> user) async {
    final safeUser = <String, dynamic>{};
    user.forEach((k, v) {
      if (v is Timestamp) {
        safeUser[k] = v.toDate().toIso8601String();
      } else if (v is DateTime) {
        safeUser[k] = v.toIso8601String();
      } else {
        safeUser[k] = v;
      }
    });
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(safeUser));
  }

  static Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

class AllumniApp extends StatelessWidget {
  const AllumniApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Allumni',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xff123c73),
        ),
        home: const BootstrapPage(),
      );
}

class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    Session.read().then((v) {
      if (mounted) setState(() => user = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return AuthPage(onLogged: (u) => setState(() => user = u));
    }
    return ShellPage(
      user: user!,
      onLogout: () async {
        await Session.clear();
        if (mounted) setState(() => user = null);
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onLogged});
  final ValueChanged<Map<String, dynamic>> onLogged;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final course = TextEditingController();
  final year = TextEditingController();
  bool register = false;
  bool busy = false;
  bool obscurePassword = true;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      showError(context, 'Preencha o e-mail e a senha.');
      return;
    }

    setState(() => busy = true);
    try {
      Map<String, dynamic> user;
      if (register) {
        if (name.text.trim().isEmpty || course.text.trim().isEmpty) {
          throw Exception('Preencha seu nome e curso.');
        }
        user = await FirebaseDb.cadastro(
          nome: name.text,
          email: email.text,
          senha: password.text,
          curso: course.text,
          anoFormatura: int.tryParse(year.text.trim()),
        );
      } else {
        user = await FirebaseDb.login(email.text, password.text);
      }
      await Session.save(user);
      if (mounted) {
        widget.onLogged(user);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.school_rounded, size: 74, color: Color(0xff123c73)),
                    const SizedBox(height: 12),
                    Text(
                      'Allumni',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text('A comunidade de ex-alunos', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_done, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Firebase Cloud Firestore Conectado',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (register) ...[
                      field(name, 'Nome completo'),
                      field(course, 'Curso'),
                      field(year, 'Ano de formatura', type: TextInputType.number),
                    ],
                    field(email, 'E-mail', type: TextInputType.emailAddress),
                    field(
                      password,
                      'Senha',
                      obscure: obscurePassword,
                      suffix: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(busy ? 'Conectando ao Firebase...' : register ? 'Criar conta' : 'Entrar'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => register = !register),
                      child: Text(register ? 'Já tenho uma conta' : 'Criar minha conta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

Widget field(TextEditingController c, String label, {bool obscure = false, TextInputType? type, Widget? suffix}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: suffix,
        ),
      ),
    );

void showError(BuildContext context, Object error) {
  var msg = error.toString().replaceFirst('Exception: ', '');
  if (msg.contains('Converting object to an encodable object') || msg.contains('Timestamp')) {
    msg = 'Erro interno ao salvar sessão. Tente novamente.';
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade800,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.user, required this.onLogout});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(user: widget.user),
      JobsTab(user: widget.user),
      EventsTab(user: widget.user),
      GroupsTab(user: widget.user),
      ProfileTab(user: widget.user, onLogout: widget.onLogout),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allumni'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Firebase Conectado',
            icon: const Icon(Icons.cloud_done_rounded, color: Colors.green),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conectado remotamente ao Cloud Firestore (alumni-d1a49).')),
              );
            },
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Vagas'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Eventos'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Grupos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Olá, ${user['nome'] ?? 'ex-aluno'}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Sua comunidade, eventos e oportunidades em tempo real com Firebase.'),
          const SizedBox(height: 20),
          FirestoreStreamList(
            title: 'Próximos eventos',
            stream: FirebaseDb.streamEventos(),
            empty: 'Nenhum evento cadastrado no Firestore.',
            builder: (x) => EventCard(event: x),
          ),
        ],
      );
}

class FirestoreStreamList extends StatelessWidget {
  const FirestoreStreamList({
    super.key,
    required this.title,
    required this.stream,
    required this.empty,
    required this.builder,
  });

  final String title, empty;
  final Stream<List<Map<String, dynamic>>> stream;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro no Firestore: ${snap.error}'),
              ),
            );
          }
          final list = snap.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(empty)))
              else
                ...list.map(builder),
            ],
          );
        },
      );
}

class JobsTab extends StatelessWidget {
  const JobsTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FirestoreStreamList(
            title: 'Vagas disponíveis',
            stream: FirebaseDb.streamVagas(),
            empty: 'Nenhuma vaga disponível no momento.',
            builder: (x) => JobCard(job: x, user: user),
          ),
        ],
      );
}

class JobCard extends StatefulWidget {
  const JobCard({super.key, required this.job, required this.user});
  final Map<String, dynamic> job, user;

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool applied = false;
  bool loading = false;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.work)),
          title: Text(widget.job['titulo'] ?? 'Vaga'),
          subtitle: Text('${widget.job['empresa'] ?? ''}\n${widget.job['localizacao'] ?? ''}'),
          isThreeLine: true,
          trailing: FilledButton.tonal(
            onPressed: (applied || loading)
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => loading = true);
                    try {
                      await FirebaseDb.candidatarVaga(widget.job['id'], widget.user);
                      if (!mounted) return;
                      setState(() => applied = true);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Candidatura gravada no Firestore com sucesso!')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                      );
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
            child: Text(applied ? 'Candidatado' : loading ? 'Enviando...' : 'Candidatar'),
          ),
        ),
      );
}

class EventsTab extends StatelessWidget {
  const EventsTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FirestoreStreamList(
            title: 'Eventos e palestras',
            stream: FirebaseDb.streamEventos(),
            empty: 'Nenhum evento disponível no momento.',
            builder: (x) => EventCard(event: x),
          ),
        ],
      );
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.event)),
          title: Text(event['titulo'] ?? 'Evento'),
          subtitle: Text('${event['resumo'] ?? event['descricao'] ?? ''}\n${event['data_formatada'] ?? event['data_evento'] ?? ''}'),
          isThreeLine: true,
        ),
      );
}

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FirestoreStreamList(
            title: 'Comunidades',
            stream: FirebaseDb.streamGrupos(),
            empty: 'Nenhum grupo cadastrado no momento.',
            builder: (g) => GroupCard(grupo: g, user: user),
          ),
        ],
      );
}

class GroupCard extends StatefulWidget {
  const GroupCard({super.key, required this.grupo, required this.user});
  final Map<String, dynamic> grupo, user;

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool joined = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final membros = widget.grupo['membros'] as List?;
    if (membros != null && membros.contains(widget.user['id'])) {
      joined = true;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.groups)),
          title: Text(widget.grupo['nome'] ?? 'Grupo'),
          subtitle: Text(widget.grupo['descricao'] ?? ''),
          trailing: OutlinedButton(
            onPressed: (joined || loading)
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => loading = true);
                    try {
                      await FirebaseDb.entrarGrupo(widget.grupo['id'], widget.user['id'] ?? '');
                      if (!mounted) return;
                      setState(() => joined = true);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Você agora é membro deste grupo no Firestore!')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                      );
                    } finally {
                      if (mounted) setState(() => loading = false);
                    }
                  },
            child: Text(joined ? 'Membro' : loading ? 'Entrando...' : 'Entrar'),
          ),
        ),
      );
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.user, required this.onLogout});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final TextEditingController name = TextEditingController(text: widget.user['nome'] ?? '');
  late final TextEditingController course = TextEditingController(text: widget.user['curso'] ?? '');
  final TextEditingController bio = TextEditingController();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final userId = widget.user['id']?.toString() ?? '';
    if (userId.isNotEmpty) {
      FirebaseDb.getPerfil(userId).then((p) {
        if (mounted) {
          bio.text = p['bio']?.toString() ?? '';
          if (p['nome'] != null) name.text = p['nome'];
          if (p['curso'] != null) course.text = p['curso'];
          setState(() => loading = false);
        }
      }).catchError((_) {
        if (mounted) setState(() => loading = false);
      });
    } else {
      loading = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 38, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 16),
          field(name, 'Nome'),
          field(course, 'Curso'),
          field(bio, 'Sobre você'),
          FilledButton(
            onPressed: (loading || saving)
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => saving = true);
                    try {
                      final userId = widget.user['id']?.toString() ?? '';
                      await FirebaseDb.updatePerfil(
                        userId,
                        nome: name.text,
                        curso: course.text,
                        bio: bio.text,
                      );
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Perfil atualizado remotamente no Firestore!')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                      );
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Salvando no Firebase...' : 'Salvar perfil'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      );
}
