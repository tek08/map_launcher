package com.alexmiller.map_launcher

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

private enum class MapType { google, amap, baidu, waze, yandexNavi, yandexMaps, citymapper, mapswithme, osmand }

private class MapModel(val mapType: MapType, val mapName: String, val packageName: String) {
  fun toMap(): Map<String, String> {
    return mapOf("mapType" to mapType.name, "mapName" to mapName, "packageName" to packageName)
  }
}

class MapLauncherPlugin(private val context: Context, private val activity: Activity, private val pm: PackageManager) : MethodCallHandler {
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "map_launcher")
      val context = registrar.activeContext()
      val activity = registrar.activity()
      val pm = context.getPackageManager()

      channel.setMethodCallHandler(MapLauncherPlugin(context, activity, pm))
    }
  }

  private val maps = listOf(
    MapModel(MapType.google, "Google Maps", "com.google.android.apps.maps"),
    MapModel(MapType.amap, "Amap", "com.autonavi.minimap"),
    MapModel(MapType.baidu, "Baidu Maps", "com.baidu.BaiduMap"),
    MapModel(MapType.waze, "Waze", "com.waze"),
    MapModel(MapType.yandexNavi, "Yandex Navigator", "ru.yandex.yandexnavi"),
    MapModel(MapType.yandexMaps, "Yandex Maps", "ru.yandex.yandexmaps"),
    MapModel(MapType.citymapper, "Citymapper", "com.citymapper.app.release"),
    MapModel(MapType.mapswithme, "MAPS.ME", "com.mapswithme.maps.pro"),
    MapModel(MapType.osmand, "OsmAnd", "net.osmand")
  )

  private fun getInstalledMaps(): List<MapModel> {
      val installedApps = pm.getInstalledApplications(0)
      val installedMaps = maps.filter { map -> installedApps.any { app -> app.packageName == map.packageName } }
      return installedMaps
  }


  private fun isMapAvailable(type: String): Boolean {
    val installedMaps = getInstalledMaps()
    return installedMaps.any { map -> map.mapType.name == type }
  }

  private fun launchGoogleMaps(url: String) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
    intent.setPackage("com.google.android.apps.maps")
    if (intent.resolveActivity(context.packageManager) != null) {
      context.startActivity(intent)
    }
  }

  private fun launchMap(mapType: MapType, url: String) {
    when (mapType) {
      MapType.google -> launchGoogleMaps(url)
      else -> {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val foundMap = maps.find { map -> map.mapType == mapType }
        if (foundMap != null) {
          intent.setPackage(foundMap.packageName)
        }
        context.startActivity(intent)
      }
    }
  }

  private fun checkMapIsAvailableAndLaunch(args: Map<String, String>): Boolean {
    if (!isMapAvailable(args["mapType"] as String)) {
      return false;
    }

    val mapType = MapType.valueOf(args["mapType"] as String)
    val url = args["url"] as String

    launchMap(mapType, url)

    return true;
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getInstalledMaps" -> {
        val installedMaps = getInstalledMaps()
        result.success(installedMaps.map { map -> map.toMap() })
      }
      "launchMapDirections" -> {
        if (!checkMapIsAvailableAndLaunch(call.arguments as Map<String, String>)) {
          var installedMaps = ""
          for (map in getInstalledMaps()) {
            installedMaps += map.mapName + ","
          }
          result.error("MAP_NOT_AVAILABLE", "Map is not installed on a device: ${installedMaps}", null)
        }
      }
      "launchMap" -> {
        if (!checkMapIsAvailableAndLaunch(call.arguments as Map<String, String>)) {
          result.error("MAP_NOT_AVAILABLE", "Map is not installed on a device", null)
        }
      }
      "isMapAvailable" -> {
        var args = call.arguments as Map<String, String>
        result.success(isMapAvailable(args["mapType"] as String))
      }
      else -> result.notImplemented()
    }
  }
}
