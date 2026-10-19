import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_image.dart';
import 'main.dart';

/// Um usuário é admin quando o documento dele em `usuarios` tem `admin: true`
/// (definido manualmente no console do Firebase).
bool isAdmin(Map<String, dynamic> user) => user['admin'] == true;

enum AdminFieldKind {
  text,

  /// Foto de capa: escolhida da galeria (salva como data URI) ou informada por link.
  image,

  /// Uma imagem por linha no formato `link | legenda` (legenda opcional). Salva como lista de `{url, legenda}`.
  gallery,
}

class AdminField {
  const AdminField(
    this.key,
    this.label, {
    this.required = false,
    this.multiline = false,
    this.hint,
    this.kind = AdminFieldKind.text,
  });
  final String key, label;
  final bool required, multiline;
  final String? hint;
  final AdminFieldKind kind;
}

/// Converte o texto "link | legenda" (uma imagem por linha) em lista de mapas.
List<Map<String, String>> parseGallery(String text) => [
      for (final raw in text.split('\n'))
        if (raw.trim().isNotEmpty)
          () {
            final cut = raw.indexOf('|');
            final url = (cut < 0 ? raw : raw.substring(0, cut)).trim();
            final caption = cut < 0 ? '' : raw.substring(cut + 1).trim();
            return {'url': url, 'legenda': caption};
          }(),
    ];

/// Descreve uma coleção do Firestore que o admin pode gerenciar pelo app.
class AdminSection {
  const AdminSection({
    required this.collection,
    required this.title,
    required this.singular,
    required this.icon,
    required this.fields,
    required this.stream,
    required this.titleKey,
    required this.subtitleKey,
    this.onCreate,
  });

  final String collection, title, singular, titleKey, subtitleKey;
  final IconData icon;
  final List<AdminField> fields;
  final Stream<List<Map<String, dynamic>>> Function() stream;

  /// Campos extras gravados somente na criação (recebe o admin logado).
  final Map<String, dynamic> Function(Map<String, dynamic> admin)? onCreate;
}

final adminSections = <AdminSection>[
  AdminSection(
    collection: 'noticias',
    title: 'Notícias',
    singular: 'notícia',
    icon: Icons.newspaper,
    titleKey: 'titulo',
    subtitleKey: 'resumo',
    stream: FirebaseDb.streamNoticias,
    fields: const [
      AdminField('titulo', 'Título', required: true),
      AdminField('resumo', 'Resumo'),
      AdminField('imagem', 'Imagem de capa', kind: AdminFieldKind.image),
      AdminField('conteudo', 'Conteúdo', required: true, multiline: true),
      AdminField(
        'imagens',
        'Imagens adicionais (uma por linha)',
        multiline: true,
        kind: AdminFieldKind.gallery,
        hint: 'https://site.com/foto.jpg | Legenda (opcional)',
      ),
    ],
    onCreate: (admin) => {'autor': admin['nome'] ?? ''},
  ),
  const AdminSection(
    collection: 'vagas',
    title: 'Vagas',
    singular: 'vaga',
    icon: Icons.work,
    titleKey: 'titulo',
    subtitleKey: 'empresa',
    stream: FirebaseDb.streamVagas,
    fields: [
      AdminField('titulo', 'Título da vaga', required: true),
      AdminField('empresa', 'Empresa', required: true),
      AdminField('localizacao', 'Localização'),
      AdminField('descricao', 'Descrição', multiline: true),
    ],
  ),
  const AdminSection(
    collection: 'eventos',
    title: 'Eventos',
    singular: 'evento',
    icon: Icons.event,
    titleKey: 'titulo',
    subtitleKey: 'data_formatada',
    stream: FirebaseDb.streamEventos,
    fields: [
      AdminField('titulo', 'Título', required: true),
      AdminField('data_formatada', 'Data e horário', required: true, hint: 'Ex.: 25/11/2026 às 19h'),
      AdminField('resumo', 'Resumo'),
      AdminField('descricao', 'Descrição', multiline: true),
    ],
  ),
  AdminSection(
    collection: 'grupos',
    title: 'Grupos',
    singular: 'grupo',
    icon: Icons.groups,
    titleKey: 'nome',
    subtitleKey: 'descricao',
    stream: FirebaseDb.streamGrupos,
    fields: const [
      AdminField('nome', 'Nome do grupo', required: true),
      AdminField('descricao', 'Descrição', multiline: true),
    ],
    onCreate: (_) => {'membros': <String>[]},
  ),
];

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: adminSections.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Painel do administrador'),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final s in adminSections) Tab(icon: Icon(s.icon), text: s.title)],
            ),
          ),
          body: TabBarView(
            children: [for (final s in adminSections) AdminSectionView(section: s, admin: user)],
          ),
        ),
      );
}

class AdminSectionView extends StatefulWidget {
  const AdminSectionView({super.key, required this.section, required this.admin});
  final AdminSection section;
  final Map<String, dynamic> admin;

  @override
  State<AdminSectionView> createState() => _AdminSectionViewState();
}

class _AdminSectionViewState extends State<AdminSectionView> {
  late final Stream<List<Map<String, dynamic>>> _stream = widget.section.stream();

  void _openForm([Map<String, dynamic>? item]) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminFormPage(section: widget.section, admin: widget.admin, item: item),
        ),
      );

  Future<void> _delete(Map<String, dynamic> item) async {
    final s = widget.section;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir ${s.singular}?'),
        content: Text('"${item[s.titleKey] ?? ''}" será removido para todos os usuários. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseDb.excluirItem(s.collection, item['id'] as String);
      messenger.showSnackBar(const SnackBar(content: Text('Excluído com sucesso.')));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: Text('Adicionar ${s.singular}'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Erro no Firestore: ${snap.error}')));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(child: Text('Nenhuma ${s.singular} cadastrada. Toque em "Adicionar".'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              final subtitle = (item[s.subtitleKey] ?? '').toString();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(s.icon)),
                  title: Text((item[s.titleKey] ?? '').toString()),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _openForm(item),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(item)),
                      IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(item)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminFormPage extends StatefulWidget {
  const AdminFormPage({super.key, required this.section, required this.admin, this.item});
  final AdminSection section;
  final Map<String, dynamic> admin;
  final Map<String, dynamic>? item;

  @override
  State<AdminFormPage> createState() => _AdminFormPageState();
}

class _AdminFormPageState extends State<AdminFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrl = {
    for (final f in widget.section.fields)
      if (f.kind != AdminFieldKind.image) f.key: TextEditingController(text: _initialText(f)),
  };
  late final Map<String, String> _images = {
    for (final f in widget.section.fields)
      if (f.kind == AdminFieldKind.image) f.key: (widget.item?[f.key] ?? '').toString(),
  };
  bool _saving = false;

  String _initialText(AdminField f) {
    final v = widget.item?[f.key];
    if (f.kind != AdminFieldKind.gallery) return (v ?? '').toString();
    return [
      for (final e in (v is List ? v : const []))
        if (e is Map)
          ((e['legenda'] ?? '').toString().isEmpty ? '${e['url']}' : '${e['url']} | ${e['legenda']}')
        else
          e.toString(),
    ].join('\n');
  }

  dynamic _value(AdminField f) => switch (f.kind) {
        AdminFieldKind.image => _images[f.key] ?? '',
        AdminFieldKind.gallery => parseGallery(_ctrl[f.key]!.text),
        AdminFieldKind.text => _ctrl[f.key]!.text.trim(),
      };

  Future<void> _pickImage(AdminField f) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 75);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // Documento do Firestore tem limite de 1 MiB; base64 aumenta ~33%.
      if (bytes.length > 600 * 1024) {
        throw Exception('Imagem muito grande (${bytes.length ~/ 1024} KB). Escolha uma menor que 600 KB.');
      }
      final mime = file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      if (mounted) setState(() => _images[f.key] = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _askImageUrl(AdminField f) async {
    final c = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link da imagem'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Usar')),
        ],
      ),
    );
    c.dispose();
    if (url == null || url.isEmpty || !mounted) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      showError(context, 'O link deve começar com http:// ou https://');
      return;
    }
    setState(() => _images[f.key] = url);
  }

  Widget _imageField(AdminField f) {
    final value = _images[f.key] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(f.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(aspectRatio: 16 / 9, child: AppImage(value)),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _saving ? null : () => _pickImage(f),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Escolher da galeria'),
            ),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _askImageUrl(f),
              icon: const Icon(Icons.link),
              label: const Text('Usar link'),
            ),
            if (value.isNotEmpty)
              TextButton.icon(
                onPressed: _saving ? null : () => setState(() => _images[f.key] = ''),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover'),
              ),
          ],
        ),
      ],
    );
  }

  bool get _editing => widget.item != null;

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final s = widget.section;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{for (final f in s.fields) f.key: _value(f)};
      await FirebaseDb.salvarItem(
        s.collection,
        widget.item?['id'] as String?,
        data,
        aoCriar: s.onCreate?.call(widget.admin) ?? const {},
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_editing ? 'Alterações salvas com sucesso!' : 'Publicado com sucesso!')),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return Scaffold(
      appBar: AppBar(title: Text('${_editing ? 'Editar' : 'Nova'} ${s.singular}')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final f in s.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: f.kind == AdminFieldKind.image
                      ? _imageField(f)
                      : TextFormField(
                          controller: _ctrl[f.key],
                          enabled: !_saving,
                          minLines: f.multiline ? 4 : 1,
                          maxLines: f.multiline ? 12 : 1,
                          keyboardType: f.kind == AdminFieldKind.gallery
                              ? TextInputType.url
                              : f.multiline
                                  ? TextInputType.multiline
                                  : TextInputType.text,
                          textCapitalization:
                              f.kind == AdminFieldKind.gallery ? TextCapitalization.none : TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: f.required ? '${f.label} *' : f.label,
                            hintText: f.hint,
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: f.multiline,
                          ),
                          validator: (v) {
                            if (f.required && (v ?? '').trim().isEmpty) return 'Campo obrigatório';
                            if (f.kind == AdminFieldKind.gallery &&
                                parseGallery(v ?? '').any((e) => !e['url']!.startsWith('http'))) {
                              return 'Cada linha deve começar com um link http(s)';
                            }
                            return null;
                          },
                        ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_saving ? 'Salvando no Firebase...' : _editing ? 'Salvar alterações' : 'Publicar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
