import 'dart:math';

import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ARMeasurementScreen extends StatefulWidget {
  const ARMeasurementScreen({super.key});

  @override
  State<ARMeasurementScreen> createState() => _ARMeasurementScreenState();
}

class _ARMeasurementScreenState extends State<ARMeasurementScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<ARAnchor> anchors = [];
  List<ARNode> nodes = [];
  String distance = "0.00 m";
  String status = "Moving your phone to scan surfaces...";

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Measurement'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          // Crosshair
          Center(
            child: Icon(
              Icons.add,
              color: Colors.white.withValues(alpha: 0.5),
              size: 40,
            ),
          ),
          // Status Overlay
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          // Distance Overlay
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "CURRENT MEASUREMENT",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.straighten,
                        color: Colors.white70,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        distance,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Reset Button
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              heroTag: "resetBtn",
              onPressed: onRemoveAllNodes,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
          // Instructions
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Text(
                anchors.isEmpty
                    ? "Tap on a grid to start"
                    : (anchors.length == 1
                          ? "Tap another point to measure"
                          : "Measurement complete"),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
    );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTap;
    this.arSessionManager!.onPlaneDetected = (int planeCount) {
      if (mounted) {
        setState(() {
          status = "Surface detected! You can now tap to measure.";
        });
      }
    };
  }

  Future<void> onPlaneOrPointTap(List<ARHitTestResult> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    var tapResult = hitTestResults.first;
    var newAnchor = ARPlaneAnchor(transformation: tapResult.worldTransform);
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

    if (didAddAnchor ?? false) {
      anchors.add(newAnchor);

      // Add a visual node (red sphere/balloon) at the anchor point
      var newNode = ARNode(
        type: NodeType.webGLB,
        uri:
            "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/RedBalloon/glTF-Binary/RedBalloon.glb",
        scale: vector.Vector3(0.015, 0.015, 0.015), // Small red point
        position: vector.Vector3(0, 0, 0),
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      bool? didAddNode = await arObjectManager!.addNode(
        newNode,
        planeAnchor: newAnchor,
      );
      if (didAddNode ?? false) {
        nodes.add(newNode);
      }

      if (anchors.length >= 2) {
        calculateDistanceBetweenAnchors();
        drawLineBetweenLastTwoPoints();
      } else {
        setState(() {
          status = "First point placed.";
        });
      }
    }
  }

  Future<void> drawLineBetweenLastTwoPoints() async {
    if (nodes.length < 2) return;

    // We can't easily get the absolute world position of nodes anchored to planes
    // directly without complex transformations if they move.
    // However, since we just placed them, we'll use their anchor positions if possible.
    // In this plugin, nodes attached to anchors have positions relative to anchor.
    // But we need to draw a line in world space.

    // A simpler way for this plugin is to add a node to the midpoint anchor
    var startPos = anchors[anchors.length - 2].transformation.getTranslation();
    var endPos = anchors.last.transformation.getTranslation();

    var distance = (startPos - endPos).length;
    var midpoint = (startPos + endPos) / 2;

    // Create a thin cylinder as a line
    var lineNode = ARNode(
      type: NodeType.webGLB,
      uri:
          "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Cylinder/glTF-Binary/Cylinder.glb",
      scale: vector.Vector3(
        0.005,
        distance / 2.0,
        0.005,
      ), // Cylinders are usually 2 units high by default
      position: midpoint,
    );

    // To rotate the line to face the other point:
    // This is a bit complex without a lookAt helper on the Node itself.
    // We'll attempt a basic alignment or just leave it as a pointer for now if rotation is too buggy.
    // But let's try basic orientation.
    vector.Vector3 direction = endPos - startPos;
    lineNode.transform = _getRotationMatrix(midpoint, direction, distance);

    bool? didAddLine = await arObjectManager!.addNode(lineNode);
    if (didAddLine ?? false) {
      nodes.add(lineNode);
    }
  }

  vector.Matrix4 _getRotationMatrix(
    vector.Vector3 position,
    vector.Vector3 direction,
    double length,
  ) {
    vector.Vector3 up = vector.Vector3(0, 1, 0);
    vector.Vector3 axis = up.cross(direction).normalized();
    double angle = acos(up.dot(direction.normalized()));

    vector.Matrix4 rotation = vector.Matrix4.identity();
    if (axis.length > 0) {
      rotation.setTranslation(position);
      rotation.rotate(axis, angle);
      rotation.scaleByVector3(vector.Vector3(0.005, length / 2.0, 0.005));
    } else {
      rotation.setTranslation(position);
      rotation.scaleByVector3(vector.Vector3(0.005, length / 2.0, 0.005));
    }
    return rotation;
  }

  Future<void> calculateDistanceBetweenAnchors() async {
    if (anchors.length < 2) return;

    var anchor1 = anchors[anchors.length - 2];
    var anchor2 = anchors.last;

    double? d = await arSessionManager!.getDistanceBetweenAnchors(
      anchor1,
      anchor2,
    );

    if (d != null) {
      setState(() {
        distance = "${d.toStringAsFixed(2)} m";
        status = "Measurement complete: $distance";
      });
    }
  }

  Future<void> onRemoveAllNodes() async {
    for (var anchor in anchors) {
      arAnchorManager!.removeAnchor(anchor);
    }
    anchors.clear();
    nodes.clear();
    setState(() {
      distance = "0.00 m";
      status = "Points cleared. Scan to start again.";
    });
  }
}
