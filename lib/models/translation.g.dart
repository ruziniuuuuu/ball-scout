// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranslationRequest _$TranslationRequestFromJson(Map<String, dynamic> json) =>
    TranslationRequest(
      text: json['text'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      domain: json['domain'] as String? ?? 'football',
      priority: json['priority'] as String? ?? 'medium',
    );

Map<String, dynamic> _$TranslationRequestToJson(TranslationRequest instance) =>
    <String, dynamic>{
      'text': instance.text,
      'sourceLanguage': instance.sourceLanguage,
      'targetLanguage': instance.targetLanguage,
      'domain': instance.domain,
      'priority': instance.priority,
    };

TranslationResult _$TranslationResultFromJson(Map<String, dynamic> json) =>
    TranslationResult(
      translatedText: json['translatedText'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      model: json['model'] as String,
      processingTime: (json['processingTime'] as num).toInt(),
      qualityScore: (json['qualityScore'] as num).toDouble(),
      originalText: json['originalText'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$TranslationResultToJson(TranslationResult instance) =>
    <String, dynamic>{
      'translatedText': instance.translatedText,
      'confidence': instance.confidence,
      'model': instance.model,
      'processingTime': instance.processingTime,
      'qualityScore': instance.qualityScore,
      'originalText': instance.originalText,
      'sourceLanguage': instance.sourceLanguage,
      'targetLanguage': instance.targetLanguage,
      'timestamp': instance.timestamp,
    };

TranslationResponse _$TranslationResponseFromJson(Map<String, dynamic> json) =>
    TranslationResponse(
      success: json['success'] as bool,
      data: json['data'] == null
          ? null
          : TranslationResult.fromJson(json['data'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : TranslationError.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$TranslationResponseToJson(
        TranslationResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'error': instance.error,
      'meta': instance.meta,
    };

TranslationError _$TranslationErrorFromJson(Map<String, dynamic> json) =>
    TranslationError(
      code: json['code'] as String,
      message: json['message'] as String,
      details: json['details'] as List<dynamic>?,
    );

Map<String, dynamic> _$TranslationErrorToJson(TranslationError instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'details': instance.details,
    };

BatchTranslationRequest _$BatchTranslationRequestFromJson(
        Map<String, dynamic> json) =>
    BatchTranslationRequest(
      requests: (json['requests'] as List<dynamic>)
          .map((e) => TranslationRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BatchTranslationRequestToJson(
        BatchTranslationRequest instance) =>
    <String, dynamic>{
      'requests': instance.requests,
    };

BatchTranslationResponse _$BatchTranslationResponseFromJson(
        Map<String, dynamic> json) =>
    BatchTranslationResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => TranslationResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] == null
          ? null
          : TranslationError.fromJson(json['error'] as Map<String, dynamic>),
      meta: json['meta'] == null
          ? null
          : BatchTranslationMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BatchTranslationResponseToJson(
        BatchTranslationResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'error': instance.error,
      'meta': instance.meta,
    };

BatchTranslationMeta _$BatchTranslationMetaFromJson(
        Map<String, dynamic> json) =>
    BatchTranslationMeta(
      total: (json['total'] as num).toInt(),
      successful: (json['successful'] as num).toInt(),
      failed: (json['failed'] as num).toInt(),
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$BatchTranslationMetaToJson(
        BatchTranslationMeta instance) =>
    <String, dynamic>{
      'total': instance.total,
      'successful': instance.successful,
      'failed': instance.failed,
      'timestamp': instance.timestamp,
    };

TranslationServiceStatus _$TranslationServiceStatusFromJson(
        Map<String, dynamic> json) =>
    TranslationServiceStatus(
      availableProviders: (json['availableProviders'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      totalProviders: (json['totalProviders'] as num).toInt(),
      fallbackChain: (json['fallbackChain'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      cache: CacheStats.fromJson(json['cache'] as Map<String, dynamic>),
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$TranslationServiceStatusToJson(
        TranslationServiceStatus instance) =>
    <String, dynamic>{
      'availableProviders': instance.availableProviders,
      'totalProviders': instance.totalProviders,
      'fallbackChain': instance.fallbackChain,
      'cache': instance.cache,
      'timestamp': instance.timestamp,
    };

CacheStats _$CacheStatsFromJson(Map<String, dynamic> json) => CacheStats(
      totalEntries: (json['totalEntries'] as num).toInt(),
      totalHits: (json['totalHits'] as num).toInt(),
      totalSize: (json['totalSize'] as num).toInt(),
      maxSize: (json['maxSize'] as num).toInt(),
      hitRate: (json['hitRate'] as num).toDouble(),
    );

Map<String, dynamic> _$CacheStatsToJson(CacheStats instance) =>
    <String, dynamic>{
      'totalEntries': instance.totalEntries,
      'totalHits': instance.totalHits,
      'totalSize': instance.totalSize,
      'maxSize': instance.maxSize,
      'hitRate': instance.hitRate,
    };
