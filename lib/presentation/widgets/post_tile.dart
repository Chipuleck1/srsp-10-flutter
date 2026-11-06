import 'package:flutter/material.dart';

import '../../data/models/post.dart';
import 'state_views.dart';

class PostTile extends StatelessWidget {
  const PostTile({
    super.key,
    required this.post,
    this.authorName,
    required this.onTap,
  });

  final Post post;
  final String? authorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text('${post.id}')),
        title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(authorName ?? 'Автор #${post.userId}'),
              if (post.isLocal) const LocalBadge(),
            ],
          ),
        ),
      ),
    );
  }
}
