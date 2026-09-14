class DocTemplate {
  final String id;
  final String title;
  final String description;
  final String content;
  final String emoji;

  const DocTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.emoji,
  });
}

class TemplateService {
  static const List<DocTemplate> all = [
    DocTemplate(
      id: 'blank',
      title: 'Blank document',
      description: 'Start from scratch',
      emoji: '📝',
      content: '',
    ),
    DocTemplate(
      id: 'book',
      title: 'Book',
      description: 'Chapters & story structure',
      emoji: '📚',
      content:
          '# Chapter 1 — Beginning\n\nWrite the opening of your book here...\n\n\n# Chapter 2 — Rising action\n\nContinue the story...\n\n\n# Chapter 3 — Climax\n\nThe turning point...\n\n\n# Chapter 4 — Ending\n\nBring the story to a close...',
    ),
    DocTemplate(
      id: 'article',
      title: 'Article',
      description: 'Title, intro, body, conclusion',
      emoji: '📰',
      content:
          'Article Title\n\n## Introduction\n\nWrite a short introduction that hooks the reader.\n\n## Main body\n\nDevelop your main ideas in clear paragraphs.\n\n## Conclusion\n\nSummarize the key points and leave a final thought.',
    ),
    DocTemplate(
      id: 'letter',
      title: 'Letter',
      description: 'Formal letter layout',
      emoji: '✉️',
      content:
          '[Your name]\n[Your address]\n[City, ZIP]\n[Date]\n\n[Recipient name]\n[Recipient address]\n\nDear [Name],\n\nI am writing to...\n\n\nYours sincerely,\n[Your name]',
    ),
    DocTemplate(
      id: 'report',
      title: 'Report',
      description: 'Structured report',
      emoji: '📊',
      content:
          'Report Title\n\n1. Executive summary\n\nBrief overview of findings.\n\n2. Introduction\n\nBackground and objectives.\n\n3. Findings\n\n- Point one\n- Point two\n- Point three\n\n4. Recommendations\n\nWhat should be done next.\n\n5. Conclusion\n\nFinal remarks.',
    ),
    DocTemplate(
      id: 'notes',
      title: 'Meeting notes',
      description: 'Agenda and action items',
      emoji: '📋',
      content:
          'Meeting notes — [Date]\n\nAttendees:\n- \n\nAgenda:\n1. \n2. \n3. \n\nDiscussion:\n\n\nAction items:\n- [ ] Task — Owner — Due date\n- [ ] Task — Owner — Due date\n\nNext meeting:',
    ),
  ];
}
