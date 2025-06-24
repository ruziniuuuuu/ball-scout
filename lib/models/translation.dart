import 'package:json_annotation/json_annotation.dart';

part 'translation.g.dart';

@JsonSerializable()
class TranslationRequest {
  final String text;
  final String sourceLanguage;
  final String targetLanguage;
  final String domain;
  final String priority;

  const TranslationRequest({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.domain = 'football',
    this.priority = 'medium',
  });

  factory TranslationRequest.fromJson(Map<String, dynamic> json) =>
      _$TranslationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationRequestToJson(this);
}

@JsonSerializable()
class TranslationResult {
  final String translatedText;
  final double confidence;
  final String model;
  final int processingTime;
  final double qualityScore;
  final String originalText;
  final String sourceLanguage;
  final String targetLanguage;
  final String timestamp;

  const TranslationResult({
    required this.translatedText,
    required this.confidence,
    required this.model,
    required this.processingTime,
    required this.qualityScore,
    required this.originalText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) =>
      _$TranslationResultFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationResultToJson(this);
}

@JsonSerializable()
class TranslationResponse {
  final bool success;
  final TranslationResult? data;
  final TranslationError? error;
  final Map<String, dynamic>? meta;

  const TranslationResponse({
    required this.success,
    this.data,
    this.error,
    this.meta,
  });

  factory TranslationResponse.fromJson(Map<String, dynamic> json) =>
      _$TranslationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationResponseToJson(this);
}

@JsonSerializable()
class TranslationError {
  final String code;
  final String message;
  final List<dynamic>? details;

  const TranslationError({
    required this.code,
    required this.message,
    this.details,
  });

  factory TranslationError.fromJson(Map<String, dynamic> json) =>
      _$TranslationErrorFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationErrorToJson(this);
}

@JsonSerializable()
class BatchTranslationRequest {
  final List<TranslationRequest> requests;

  const BatchTranslationRequest({
    required this.requests,
  });

  factory BatchTranslationRequest.fromJson(Map<String, dynamic> json) =>
      _$BatchTranslationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$BatchTranslationRequestToJson(this);
}

@JsonSerializable()
class BatchTranslationResponse {
  final bool success;
  final List<TranslationResult>? data;
  final TranslationError? error;
  final BatchTranslationMeta? meta;

  const BatchTranslationResponse({
    required this.success,
    this.data,
    this.error,
    this.meta,
  });

  factory BatchTranslationResponse.fromJson(Map<String, dynamic> json) =>
      _$BatchTranslationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BatchTranslationResponseToJson(this);
}

@JsonSerializable()
class BatchTranslationMeta {
  final int total;
  final int successful;
  final int failed;
  final String timestamp;

  const BatchTranslationMeta({
    required this.total,
    required this.successful,
    required this.failed,
    required this.timestamp,
  });

  factory BatchTranslationMeta.fromJson(Map<String, dynamic> json) =>
      _$BatchTranslationMetaFromJson(json);

  Map<String, dynamic> toJson() => _$BatchTranslationMetaToJson(this);
}

@JsonSerializable()
class TranslationServiceStatus {
  final List<String> availableProviders;
  final int totalProviders;
  final List<String> fallbackChain;
  final CacheStats cache;
  final String timestamp;

  const TranslationServiceStatus({
    required this.availableProviders,
    required this.totalProviders,
    required this.fallbackChain,
    required this.cache,
    required this.timestamp,
  });

  factory TranslationServiceStatus.fromJson(Map<String, dynamic> json) =>
      _$TranslationServiceStatusFromJson(json);

  Map<String, dynamic> toJson() => _$TranslationServiceStatusToJson(this);
}

@JsonSerializable()
class CacheStats {
  final int totalEntries;
  final int totalHits;
  final int totalSize;
  final int maxSize;
  final double hitRate;

  const CacheStats({
    required this.totalEntries,
    required this.totalHits,
    required this.totalSize,
    required this.maxSize,
    required this.hitRate,
  });

  factory CacheStats.fromJson(Map<String, dynamic> json) =>
      _$CacheStatsFromJson(json);

  Map<String, dynamic> toJson() => _$CacheStatsToJson(this);
}
