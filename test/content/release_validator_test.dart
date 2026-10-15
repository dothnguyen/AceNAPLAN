import 'dart:convert';
import 'dart:typed_data';

import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/content/canonical_question_digest.dart';
import 'package:ace_naplan5/domain/content/release_validator.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

QuestionRevision _item(String id, String family, List<QuestionAsset> assets) {
  final draft = QuestionRevision(
    itemId: id,
    variantId: family == 'C-SP-01'
        ? 'distinct_word_and_context_recording'
        : 'distinct_word_and_misspelling',
    familyId: family,
    revision: 1,
    contentSchemaVersion: 1,
    bankVersion: 'synthetic',
    topic: 'spelling',
    domain: QuestionDomain.conventions,
    difficulty: QuestionDifficulty.introductory,
    curriculumReferences: const ['synthetic'],
    skillReferences: [
      family == 'C-SP-01'
          ? 'Spell a word from contextual audio dictation'
          : 'Correct a misspelled word in context'
    ],
    provenance: 'synthetic',
    license: 'synthetic',
    contentDigest: 'pending',
    reviewRecordId: 'review-$id',
    prompt: 'Prompt $id',
    stimulusDescription: 'Stimulus $id',
    hint: 'Hint',
    explanation: 'Explanation',
    assets: assets,
    answerRule: SpellingRule(target: 'w$id', scoringPolicyVersion: 1),
  );
  return _copy(draft, contentDigest: canonicalQuestionDigest(draft));
}

QuestionRevision _copy(QuestionRevision item,
        {String? contentDigest,
        String? prompt,
        String? stimulusDescription,
        String? explanation,
        List<QuestionAsset>? assets,
        AnswerRule? answerRule}) =>
    QuestionRevision(
      itemId: item.itemId,
      variantId: item.variantId,
      familyId: item.familyId,
      revision: item.revision,
      contentSchemaVersion: item.contentSchemaVersion,
      bankVersion: item.bankVersion,
      topic: item.topic,
      domain: item.domain,
      difficulty: item.difficulty,
      curriculumReferences: item.curriculumReferences,
      skillReferences: item.skillReferences,
      provenance: item.provenance,
      license: item.license,
      contentDigest: contentDigest ?? item.contentDigest,
      reviewRecordId: item.reviewRecordId,
      prompt: prompt ?? item.prompt,
      stimulusDescription: stimulusDescription ?? item.stimulusDescription,
      hint: item.hint,
      explanation: explanation ?? item.explanation,
      assets: assets ?? item.assets,
      answerRule: answerRule ?? item.answerRule,
    );

Uint8List _wave() {
  final bytes = Uint8List(46);
  final view = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  view.setUint32(4, 38, Endian.little);
  bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, 8000, Endian.little);
  view.setUint32(28, 8000, Endian.little);
  view.setUint16(32, 1, Endian.little);
  view.setUint16(34, 8, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  view.setUint32(40, 1, Endian.little);
  bytes[44] = 128;
  return bytes;
}

void main() {
  test('SHA-256 checks actual bytes against a standard test vector', () {
    expect(sha256Hex(Uint8List.fromList(utf8.encode('abc'))),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('canonical question has stable versioned UTF-8 bytes', () {
    final item = _item('a', 'C-SP-02', []);
    expect(canonicalQuestionDigest(item),
        '5860269259a709714b41fb2cb9643a3cacf63b2f11274c392f40938d04beaa16');
    expect(utf8.decode(canonicalQuestionBytes(item)),
        contains('"digestVersion":1'));
    expect(canonicalQuestionDigest(_copy(item, contentDigest: 'another')),
        item.contentDigest);
  });

  test('review binding rejects changed prompt, key, explanation and asset', () {
    final asset = QuestionAsset(
        id: 'picture', digest: ''.padLeft(64, 'a'), description: 'A picture');
    final item = _item('a', 'C-SP-02', [asset]);
    final review = {
      item.reviewRecordId: {
        'id': item.itemId,
        'revision': item.revision,
        'digest': item.contentDigest,
        'status': 'approved',
        'reviewer': 'Synthetic reviewer',
        'reviewed_at': '2026-01-01',
      }
    };
    List<String> check(QuestionRevision candidate,
            {Map<String, dynamic>? itemReviews}) =>
        validateReleaseContent(
          items: [candidate],
          catalogue: const {
            'release_bank': true,
            'status': 'release_approved',
            'families': []
          },
          bundledBytes: const {},
          assetManifest: const {},
          itemReviews: itemReviews ?? review,
          audioReviews: const {},
          dictationAlternatives: const {},
          variationValues: const {},
        );
    bool mismatch(List<String> issues) =>
        issues.any((issue) => issue.contains('content digest mismatch'));

    expect(mismatch(check(item)), isFalse);
    expect(mismatch(check(_copy(item, prompt: 'Changed prompt'))), isTrue);
    expect(
        mismatch(check(_copy(item,
            answerRule:
                SpellingRule(target: 'changed', scoringPolicyVersion: 1)))),
        isTrue);
    expect(mismatch(check(_copy(item, explanation: 'Changed explanation'))),
        isTrue);
    expect(
        mismatch(check(_copy(item, assets: [
          QuestionAsset(
              id: asset.id,
              digest: asset.digest,
              description: 'Changed picture')
        ]))),
        isTrue);
    expect(
        mismatch(check(item, itemReviews: {
          item.reviewRecordId: {
            ...review[item.reviewRecordId]!,
            'digest': ''.padLeft(64, 'b')
          }
        })),
        isTrue);
  });

  test('draft, missing/tampered assets and unreviewed records fail closed', () {
    final bytes = Uint8List.fromList(utf8.encode('asset bytes'));
    final digest = sha256Hex(bytes);
    final item = _item('a', 'C-SP-02',
        [QuestionAsset(id: 'visual', digest: digest, description: 'A visual')]);
    final catalogue = <String, dynamic>{
      'schema_version': 1,
      'status': 'draft_planning',
      'release_bank': false,
      'families': [
        {
          'id': 'C-SP-02',
          'domain': 'conventions',
          'topic': 'spelling',
          'skill': 'Correct a misspelled word in context',
          'response_format': 'spelling_entry',
          'difficulty_targets': {'introductory': 10, 'developing': 10},
          'variants': [
            {'id': 'distinct_word_and_misspelling', 'target_item_count': 20}
          ],
          'variation_fields': ['target_word', 'context']
        }
      ]
    };
    List<String> check({
      Map<String, Uint8List>? files,
      Map<String, dynamic>? manifest,
      Map<String, dynamic>? reviews,
      Map<String, Map<String, String>>? variation,
    }) =>
        validateReleaseContent(
          items: [item],
          catalogue: catalogue,
          bundledBytes: files ?? {'assets/visual.bin': bytes},
          assetManifest: manifest ??
              {
                'visual': {
                  'path': 'assets/visual.bin',
                  'digest': digest,
                  'kind': 'visual'
                }
              },
          itemReviews: reviews ??
              {
                'review-a': {
                  'id': 'a',
                  'digest': item.contentDigest,
                  'revision': 1,
                  'status': 'approved',
                  'reviewer': 'Synthetic reviewer',
                  'reviewed_at': '2026-01-01'
                }
              },
          audioReviews: {},
          dictationAlternatives: {},
          variationValues: variation ??
              {
                'a': {'target_word': 'wa', 'context': 'sentence'}
              },
        );
    expect(check(), contains(contains('draft')));
    expect(check(files: {}), contains(contains('Missing asset bytes')));
    expect(check(manifest: {'visual': 'malformed'}),
        contains(contains('Missing asset path')));
    expect(
        check(files: {
          'assets/visual.bin': Uint8List.fromList([1])
        }),
        contains(contains('Asset digest mismatch')));
    expect(
        check(manifest: {
          'visual': {
            'path': 'assets/../escape',
            'digest': digest,
            'kind': 'visual'
          }
        }),
        contains(contains('Unsafe asset path')));
    expect(check(reviews: {}), contains(contains('unreviewed item')));
    expect(
        check(reviews: {
          'review-a': {
            'id': 'a',
            'digest': item.contentDigest,
            'revision': 2,
            'status': 'approved',
            'reviewer': 'Synthetic reviewer',
            'reviewed_at': '2026-01-01'
          }
        }),
        contains(contains('unreviewed item')));
    expect(
        check(variation: {
          'a': {'target_word': 'another', 'context': 'sentence'}
        }),
        contains(contains('target_word does not match content')));
    expect(
        check(variation: {
          'a': {'target_word': '', 'context': 'sentence'}
        }),
        contains(contains('Missing declared variation')));
  });

  test('dictation requires valid reviewed audio and correction mapping', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final digest = sha256Hex(bytes);
    final dictation = _item('dictation', 'C-SP-01',
        [QuestionAsset(id: 'audio', digest: digest, description: 'Recording')]);
    final issues = validateReleaseContent(
      items: [dictation],
      catalogue: {
        'schema_version': 1,
        'status': 'release_approved',
        'release_bank': true,
        'families': [
          {
            'id': 'C-SP-01',
            'domain': 'conventions',
            'topic': 'spelling',
            'skill': 'Spell a word from contextual audio dictation',
            'response_format': 'spelling_entry',
            'difficulty_targets': {'introductory': 10, 'developing': 10},
            'variants': [
              {
                'id': 'distinct_word_and_context_recording',
                'target_item_count': 20
              }
            ],
            'variation_fields': ['target_word', 'context']
          }
        ]
      },
      bundledBytes: {'assets/audio.wav': bytes},
      assetManifest: {
        'audio': {'path': 'assets/audio.wav', 'digest': digest, 'kind': 'audio'}
      },
      itemReviews: {
        'review-dictation': {
          'id': 'dictation',
          'digest': dictation.contentDigest,
          'revision': 1,
          'status': 'approved',
          'reviewer': 'Synthetic reviewer',
          'reviewed_at': '2026-01-01'
        }
      },
      audioReviews: {
        'audio': {'id': 'audio', 'digest': digest, 'status': 'draft'}
      },
      dictationAlternatives: {},
      variationValues: {
        'dictation': {'target_word': 'word', 'context': 'sentence'}
      },
    );
    expect(issues, contains(contains('Malformed audio')));
    expect(issues, contains(contains('unreviewed audio')));
    expect(issues, contains(contains('accessible correction alternative')));
  });

  test('reviewed dictation audio is bound to its item and accessible task', () {
    final bytes = _wave();
    final digest = sha256Hex(bytes);
    final dictation = _item('dictation', 'C-SP-01',
        [QuestionAsset(id: 'audio', digest: digest, description: 'Recording')]);
    final correction = _item('correction', 'C-SP-02', []);
    final itemReviews = {
      for (final item in [dictation, correction])
        item.reviewRecordId: {
          'id': item.itemId,
          'revision': item.revision,
          'digest': item.contentDigest,
          'status': 'approved',
          'reviewer': 'Synthetic reviewer',
          'reviewed_at': '2026-01-01'
        }
    };
    List<String> check({
      String audioItemId = 'dictation',
      String alternativeId = 'correction',
      String targetWord = 'wdictation',
      String context =
          'wdictation. Please write wdictation in your book. wdictation.',
      String transcript =
          'wdictation. Please write wdictation in your book. wdictation.',
    }) =>
        validateReleaseContent(
          items: [dictation, correction],
          catalogue: {
            'schema_version': 1,
            'status': 'release_approved',
            'release_bank': true,
            'families': [
              for (final item in [dictation, correction])
                {
                  'id': item.familyId,
                  'variation_fields': ['target_word', 'context'],
                }
            ]
          },
          bundledBytes: {'assets/audio.wav': bytes},
          assetManifest: {
            'audio': {
              'path': 'assets/audio.wav',
              'digest': digest,
              'kind': 'audio'
            }
          },
          itemReviews: itemReviews,
          audioReviews: {
            'audio': {
              'id': 'audio',
              'item_id': audioItemId,
              'digest': digest,
              'status': 'approved',
              'reviewer': 'Synthetic reviewer',
              'reviewed_at': '2026-01-01',
              'target_word': targetWord,
              'transcript': transcript,
              'provenance': 'Synthetic fixture',
              'rights': 'Synthetic fixture'
            }
          },
          dictationAlternatives: {'dictation': alternativeId},
          variationValues: {
            'dictation': {'target_word': 'wdictation', 'context': context},
            'correction': {
              'target_word': 'wcorrection',
              'context': 'Stimulus correction'
            }
          },
        );
    expect(check(), isNot(contains(contains('Malformed audio'))));
    expect(check(), isNot(contains(contains('unreviewed audio'))));
    expect(check(), isNot(contains(contains('accessible correction'))));
    expect(check(audioItemId: 'other'), contains(contains('unreviewed audio')));
    expect(check(targetWord: 'other'),
        contains(contains('transcript or target mismatch')));
    expect(check(transcript: 'wdictation'),
        contains(contains('transcript or target mismatch')));
    expect(check(context: 'forged context'),
        contains(contains('context does not match content')));
    expect(check(alternativeId: 'dictation'),
        contains(contains('accessible correction')));
  });

  test('identical declared parameters are rejected even with different prompts',
      () {
    final one = _item('one', 'C-SP-02', []);
    final two = _copy(_item('two', 'C-SP-02', []),
        stimulusDescription: one.stimulusDescription,
        answerRule: SpellingRule(target: 'wone', scoringPolicyVersion: 1));
    final issues = validateReleaseContent(
      items: [one, two],
      catalogue: {
        'schema_version': 1,
        'release_bank': true,
        'status': 'release_approved',
        'families': [
          {
            'id': 'C-SP-02',
            'domain': 'conventions',
            'topic': 'spelling',
            'skill': 'Correct a misspelled word in context',
            'response_format': 'spelling_entry',
            'difficulty_targets': {'introductory': 10, 'developing': 10},
            'variants': [
              {'id': 'distinct_word_and_misspelling', 'target_item_count': 20}
            ],
            'variation_fields': ['target_word', 'context']
          }
        ]
      },
      bundledBytes: {},
      assetManifest: {},
      itemReviews: {},
      audioReviews: {},
      dictationAlternatives: {},
      variationValues: {
        'one': {'target_word': 'wone', 'context': one.stimulusDescription},
        'two': {'target_word': 'wone', 'context': one.stimulusDescription},
      },
    );
    expect(issues, contains(contains('Trivially repeated variation')));
    expect(issues, contains(contains('Insufficient declared variation')));
  });

  test('forged context cannot make repeated correction stimuli distinct', () {
    final one = _item('one', 'C-SP-02', []);
    final two = _copy(_item('two', 'C-SP-02', []),
        stimulusDescription: one.stimulusDescription);
    List<String> check(Map<String, Map<String, String>> variation) =>
        validateReleaseContent(
          items: [one, two],
          catalogue: {
            'release_bank': true,
            'status': 'release_approved',
            'families': [
              {
                'id': 'C-SP-02',
                'variation_fields': ['target_word', 'context']
              }
            ]
          },
          bundledBytes: {},
          assetManifest: {},
          itemReviews: {},
          audioReviews: {},
          dictationAlternatives: {},
          variationValues: variation,
        );

    final forged = check({
      'one': {'target_word': 'wone', 'context': 'new sentence one'},
      'two': {'target_word': 'wtwo', 'context': 'new sentence two'},
    });
    expect(forged, contains(contains('context does not match content')));
    expect(forged, contains(contains('Insufficient declared variation')));

    final repeated = check({
      'one': {'target_word': 'wone', 'context': one.stimulusDescription},
      'two': {'target_word': 'wtwo', 'context': one.stimulusDescription},
    });
    expect(repeated, contains(contains('Insufficient declared variation')));

    final changed = _copy(two, stimulusDescription: 'A different sentence.');
    final accepted = validateReleaseContent(
      items: [one, changed],
      catalogue: {
        'release_bank': true,
        'status': 'release_approved',
        'families': [
          {
            'id': 'C-SP-02',
            'variation_fields': ['target_word', 'context']
          }
        ]
      },
      bundledBytes: {},
      assetManifest: {},
      itemReviews: {},
      audioReviews: {},
      dictationAlternatives: {},
      variationValues: {
        'one': {'target_word': 'wone', 'context': one.stimulusDescription},
        'two': {'target_word': 'wtwo', 'context': changed.stimulusDescription}
      },
    );
    expect(accepted, isNot(contains(contains('variation'))));
    expect(accepted, isNot(contains(contains('does not match content'))));
  });

  test('relationship claims fail closed even when text contains the value', () {
    final item = _item('one', 'C-SP-02', []);
    final issues = validateReleaseContent(
      items: [item],
      catalogue: {
        'release_bank': true,
        'status': 'release_approved',
        'families': [
          {
            'id': 'C-SP-02',
            'variation_fields': ['relationship']
          }
        ]
      },
      bundledBytes: {},
      assetManifest: {},
      itemReviews: {},
      audioReviews: {},
      dictationAlternatives: {},
      variationValues: {
        'one': {'relationship': 'Prompt one'}
      },
    );
    expect(issues, contains(contains('Unsupported variation binding')));
  });
}
