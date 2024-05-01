import 'dart:convert';

import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// This is an extension to make it easier to call
/// [showAndUploadToGitHub].
extension BetterFeedbackX on FeedbackController {
  /// Example usage:
  /// ```dart
  /// import 'package:feedback_github/feedback_github.dart';
  ///
  /// RaisedButton(
  ///   child: Text('Click me'),
  ///   onPressed: (){
  ///     BetterFeedback.of(context).showAndUploadToGitHub
  ///       username: 'username',
  ///       repository: 'repository',
  ///       authToken: 'github_pat_token',
  ///       labels: ['feedback'], // This is the default value
  ///       assignees: ['dash'],
  ///       customMarkdown: '**Below are system info**', // no pass to the parameter
  ///       imageId: 'unique-id',
  ///     );
  ///   }
  /// )
  /// ```
  ///
  /// The API token (Personal Access Token) needs access to:
  ///   - issues (write)
  ///   - content (write)
  ///   - metadata (read)
  ///
  /// It is assumed that the branch `issue_images` exists for [repository]
  void showAndUploadToGitHub({
    required String username,
    required String repository,
    required String authToken,
    List<String>? labels,
    List<String>? assignees,
    String? customMarkdown,
    required String imageId,
    String? githubUrl,
    http.Client? client,
  }) {
    show(uploadToGitLab(
      username: username,
      repository: repository,
      authToken: authToken,
      labels: labels,
      assignees: assignees,
      customMarkdown: customMarkdown,
      imageId: imageId,
      githubUrl: githubUrl,
      client: client,
    ));
  }
}

/// See [BetterFeedbackX.showAndUploadToGitHub].
/// This is just [visibleForTesting].
@visibleForTesting
OnFeedbackCallback uploadToGitLab({
  required String username,
  required String repository,
  required String authToken,
  List<String>? labels,
  List<String>? assignees,
  String? customMarkdown,
  required String imageId,
  String? githubUrl,
  http.Client? client,
}) {
  final httpClient = client ?? http.Client();
  final baseUrl = githubUrl ?? 'api.github.com';

  return (UserFeedback feedback) async {
    var uri = Uri.https(
      baseUrl,
      'repos/$username/$repository/issues',
    );

    // upload image to /issue_images branch
    var response = await httpClient.put(
      Uri.https(
        baseUrl,
        'repos/$username/$repository/contents/issue_images/$imageId.png',
      ),
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'message': imageId,
        'content': base64Encode(feedback.screenshot),
        'branch': 'issue_images',
      }),
    );

    if (response.statusCode == 201) {
      final imageUrl = jsonDecode(response.body)['content']['download_url'];

      // title contains first 20 characters of message, with a default for empty feedback
      final title = feedback.text.length > 20
          ? '${feedback.text.substring(0, 20)}...'
          : feedback.text.isEmpty
              ? 'New Feedback'
              : feedback.text;
      // body contains message and optional logs
      // TODO: optional logs === customMarkdown: '**Below are system info**', 目前，暂时不需要。
      // TODO：后续，添加一些可以获取，device Info；app info 的信息。
      final body = '''${feedback.text}
![]($imageUrl)
${customMarkdown ?? ''}
''';

      uri = Uri.https(
        baseUrl,
        'repos/$username/$repository/issues',
      );

      // https://docs.github.com/en/rest/issues/issues?apiVersion=2022-11-28#create-an-issue
      // labels are //labels: ['feedback'],
      // feedback.extra?['feedback_type'].split('.').last
      // "bugReport"
      //  feedback.extra?['feedback_type']
      // "FeedbackType.bugReport"
      if (feedback.extra != null && feedback.extra.isNotEmpty) {
          final feedback_type = feedback.extra?['feedback_type'].split('.').last;
          if (feedback_type == 'bugReport'){labels?.add('bug report');}
          if (feedback_type == 'featureRequest'){labels?.add('feature request');}
      }
      response = await httpClient.post(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'title': title,
          'body': body,
          'labels': labels,
          if (assignees != null && assignees.isNotEmpty) 'assignees': assignees,
        }),
      );

      // TODO error handling
    }
  };
}
