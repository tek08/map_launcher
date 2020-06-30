import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum MapType {
  apple,
  google,
  amap,
  baidu,
  waze,
  yandexNavi,
  yandexMaps,
  citymapper,
  mapswithme,
  osmand
}

String _enumToString(o) => o.toString().split('.').last;

T _enumFromString<T>(Iterable<T> values, String value) {
  return values.firstWhere((type) => type.toString().split('.').last == value,
      orElse: () => null);
}

class Coords {
  final double latitude;
  final double longitude;

  Coords(this.latitude, this.longitude);
}

class AvailableMap {
  String mapName;
  MapType mapType;
  ImageProvider icon;

  AvailableMap({this.mapName, this.mapType, this.icon});

  static AvailableMap fromJson(json) {
    return AvailableMap(
      mapName: json['mapName'],
      mapType: _enumFromString(MapType.values, json['mapType']),
      icon: _SvgImage(
        'assets/svg/${json['mapType']}.svg',
        package: 'map_launcher',
      ),
    );
  }

  Future<void> showMarker({
    @required Coords coords,
    @required String title,
    @required String description,
  }) {
    return MapLauncher.launchMap(
      mapType: mapType,
      coords: coords,
      title: title,
      description: description,
    );
  }

  @override
  String toString() {
    return 'AvailableMap { mapName: $mapName, mapType: ${_enumToString(mapType)} }';
  }
}

class _SvgImage extends AssetBundleImageProvider {
  const _SvgImage(
    this.assetName, {
    this.scale = 1.0,
    this.bundle,
    this.package,
  })  : assert(assetName != null),
        assert(scale != null);

  final String assetName;
  String get keyName =>
      package == null ? assetName : 'packages/$package/$assetName';
  final double scale;
  final AssetBundle bundle;
  final String package;

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetBundleImageKey>(AssetBundleImageKey(
      bundle: bundle ?? configuration.bundle ?? rootBundle,
      name: keyName,
      scale: scale,
    ));
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _SvgImage &&
        other.keyName == keyName &&
        other.scale == scale &&
        other.bundle == bundle;
  }

  @override
  int get hashCode => hashValues(keyName, scale, bundle);

  @override
  ImageStreamCompleter load(AssetBundleImageKey key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
    );
  }

  Future<Codec> _loadAsync(
      AssetBundleImageKey key, DecoderCallback decode) async {
    Size size = Size(256, 256);

    final Uint8List bytes = await key.bundle
        .loadString(key.name)
        .then((String rawSvg) => svg.fromSvgString(rawSvg, rawSvg))
        .then((DrawableRoot svg) {
          final ratio = svg.viewport.viewBox.aspectRatio;
          size = (ratio > 1)
              ? Size(size.width, size.width / ratio)
              : Size(size.height * ratio, size.height);
          return svg.toPicture(size: size, clipToViewBox: false);
        })
        .then((Picture picture) {
          return picture.toImage(size.width.toInt(), size.height.toInt());
        })
        .then((image) => image.toByteData(format: ImageByteFormat.png))
        .then((ByteData byteData) => byteData.buffer.asUint8List());

    return decode(
      bytes,
      cacheHeight: size.height.toInt(),
      cacheWidth: size.width.toInt(),
    );
  }
}

String _getMapUrl(
  MapType mapType,
  Coords coords, [
  String title,
  String description,
]) {
  switch (mapType) {
    case MapType.google:
      if (Platform.isIOS) {
        return 'comgooglemaps://?q=${coords.latitude},${coords.longitude}($title)';
      }
      return 'geo:0,0?q=${coords.latitude},${coords.longitude}($title)';
    case MapType.amap:
      return '${Platform.isIOS ? 'ios' : 'android'}amap://viewMap?sourceApplication=map_launcher&poiname=$title&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&dev=0';
    case MapType.baidu:
      return 'baidumap://map/marker?location=${coords.latitude},${coords.longitude}&title=$title&content=$description&traffic=on&src=com.map_launcher&coord_type=gcj02&zoom=18';
    case MapType.apple:
      return 'http://maps.apple.com/maps?saddr=${coords.latitude},${coords.longitude}';
    case MapType.waze:
      return 'waze://?ll=${coords.latitude},${coords.longitude}&zoom=10';
    case MapType.yandexNavi:
      return 'yandexnavi://show_point_on_map?lat=${coords.latitude}&lon=${coords.longitude}&zoom=16&no-balloon=0&desc=$title';
    case MapType.yandexMaps:
      return 'yandexmaps://maps.yandex.ru/?pt=${coords.longitude},${coords.latitude}&z=16&l=map';
    case MapType.citymapper:
      return 'citymapper://directions?endcoord=${coords.latitude},${coords.longitude}&endname=$title';
    case MapType.mapswithme:
      return "mapsme://map?v=1&ll=${coords.latitude},${coords.longitude}&n=$title";
    case MapType.osmand:
      if (Platform.isIOS) {
        return 'osmandmaps://navigate?lat=${coords.latitude}&lon=${coords.longitude}&title=$title';
      }
      return 'osmand.navigation:q=${coords.latitude},${coords.longitude}';
    default:
      return null;
  }
}

String _getMapUrlDirections(
    MapType mapType, String destinationAddress, Coords coords) {
  switch (mapType) {
    case MapType.google:
      if (Platform.isIOS) {
        return 'comgooglemaps://?daddr=$destinationAddress';
      }
      return 'https://maps.google.com/maps?daddr=$destinationAddress'; // no android yet
    case MapType.amap:
      return '${Platform.isIOS ? 'ios' : 'android'}amap://route/plan?sid=&slat=&slon=&sname=A&did=&dlat=${coords.latitude}&dlon=${coords.longitude}';
    case MapType.baidu:
      return 'baidumap://map/direction?destination=latlng:${coords.latitude},${coords.longitude}&mode=driving';
    case MapType.apple:
      return 'http://maps.apple.com/maps?daddr=$destinationAddress';
    // TODO(someone): Implement the rest of these links.
//    case MapType.waze:
//      return 'waze://?ll=${coords.latitude},${coords.longitude}&zoom=10';
//    case MapType.yandexNavi:
//      return 'yandexnavi://show_point_on_map?lat=${coords.latitude}&lon=${coords.longitude}&zoom=16&no-balloon=0&desc=$title';
//    case MapType.yandexMaps:
//      return 'yandexmaps://maps.yandex.ru/?pt=${coords.longitude},${coords.latitude}&z=16&l=map';
//    case MapType.citymapper:
//      return 'citymapper://directions?endcoord=${coords.latitude},${coords.longitude}&endname=$title';
//    case MapType.mapswithme:
//      return "mapsme://map?v=1&ll=${coords.latitude},${coords.longitude}&n=$title";
//    case MapType.osmand:
//      if (Platform.isIOS) {
//        return 'osmandmaps://navigate?lat=${coords.latitude}&lon=${coords.longitude}&title=$title';
//      }
//      return 'osmand.navigation:q=${coords.latitude},${coords.longitude}';
    default:
      return null;
  }
}

class MapLauncher {
  static const MethodChannel _channel = const MethodChannel('map_launcher');

  static Future<List<AvailableMap>> get installedMaps async {
    final maps = await _channel.invokeMethod('getInstalledMaps');
    return List<AvailableMap>.from(
      maps.map((map) => AvailableMap.fromJson(map)),
    );
  }

  static Future<dynamic> launchMapDirections({
    @required MapType mapType,
    @required String destinationAddress,
    @required Coords coords,
  }) async {
    final url = _getMapUrlDirections(mapType, destinationAddress, coords);

    final Map<String, String> args = {
      'mapType': _enumToString(mapType),
      'url': Uri.encodeFull(url),
      'destinationAddress': destinationAddress,
    };
    return _channel.invokeMethod('launchMapDirections', args);
  }

  static Future<dynamic> launchMap({
    @required MapType mapType,
    @required Coords coords,
    @required String title,
    @required String description,
  }) async {
    final url = _getMapUrl(mapType, coords, title, description);

    final Map<String, String> args = {
      'mapType': _enumToString(mapType),
      'url': Uri.encodeFull(url),
      'title': title,
      'description': description,
      'latitude': coords.latitude.toString(),
      'longitude': coords.longitude.toString(),
    };
    return _channel.invokeMethod('launchMap', args);
  }

  static Future<bool> isMapAvailable(MapType mapType) async {
    return _channel.invokeMethod(
      'isMapAvailable',
      {'mapType': _enumToString(mapType)},
    );
  }
}
