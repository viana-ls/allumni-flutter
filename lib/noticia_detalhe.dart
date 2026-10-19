import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin.dart';
import 'app_image.dart';
import 'main.dart';

/// Tela para ler a notícia completa com fotos, resumo e conteúdo.
class NoticiaDetalhePage extends StatelessWidget {
  const NoticiaDetalhePage({
    super.key,
    required this.news,
    this.user,
    this.onDeleted,
  });

  final Map<String, dynamic> news;
  final Map<String, dynamic>? user;
  final VoidCallback? onDeleted;

  static String _data(dynamic v) {
    if (v is! Timestamp) return '';
    final d = v.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _excluir(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir notícia?'),
        content: Text('"${news['titulo'] ?? ''}" será excluída definitivamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final id = news['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        await FirebaseDb.excluirItem('noticias', id);
      }
      if (!context.mounted) return;
      Navigator.of(context).pop(); // fecha a tela de detalhes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notícia excluída com sucesso.')),
      );
      onDeleted?.call();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  void _editar(BuildContext context) {
    if (user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminFormPage(section: adminSections.first, admin: user!, item: news),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = user != null && isAdmin(user!);
    final titulo = firstText([news['titulo']]);
    final resumo = firstText([news['resumo']]);
    final conteudo = firstText([news['conteudo']]);
    final capa = firstText([news['imagem']]);
    final autor = firstText([news['autor']]);
    final data = _data(news['criado_em']);
    final byline = [if (autor.isNotEmpty) autor, if (data.isNotEmpty) data].join(' • ');

    final galeria = [
      for (final e in (news['imagens'] is List ? news['imagens'] as List : const []))
        if (e is Map && firstText([e['url']]).isNotEmpty) e,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notícia'),
        actions: [
          if (admin) ...[
            IconButton(
              tooltip: 'Editar notícia',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editar(context),
            ),
            IconButton(
              tooltip: 'Excluir notícia',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _excluir(context),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (capa.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AppImage(capa),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo.isEmpty ? 'Sem título' : titulo,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (byline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(byline, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
                if (resumo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                    ),
                    child: Text(
                      resumo,
                      style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                if (conteudo.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    conteudo,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
                for (final img in galeria) ...[
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: AppImage(img['url'].toString(), fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  if (firstText([img['legenda']]).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        firstText([img['legenda']]),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
