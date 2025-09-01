// Copyright (C) 2023 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR BSD-3-Clause
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick.Controls

Window {
    id: mainWindow
    width: 800
    height: 600
    visible: true
    title: qsTr("Pacman Game")
    color: "black"

    Component.onCompleted: {
        requestActivate()  // 激活窗口
        inputHandler.forceActiveFocus()  // 强制键盘输入Item获得焦点
        console.log("Window activated")
    }

    onActiveChanged: {
        console.log("Window active:", active)
        if (!active) {
            requestActivate()  // 保持窗口激活
            inputHandler.forceActiveFocus()  // 恢复键盘输入焦点
        }
    }

    // 键盘输入处理
    Item {
        id: inputHandler
        anchors.fill: parent
        focus: true  // 请求焦点以接收键盘事件

        Keys.onPressed: (event) => {
            console.log("InputHandler key:", event.key)
            var step = 50
            var positional = ballNode.position
            var newX = positional.x
            var newZ = positional.z
            if (event.key === Qt.Key_W) {
                newZ -= step
            } else if (event.key === Qt.Key_S) {
                newZ += step
            } else if (event.key === Qt.Key_A) {
                newX -= step
            } else if (event.key === Qt.Key_D) {
                newX += step
            }
            // 碰撞检测：限制不超出墙体
            newX = Math.max(-1000, Math.min(1000, newX))
            newZ = Math.max(-1000, Math.min(1000, newZ))
            ballNode.position = Qt.vector3d(newX, positional.y, newZ)
            console.log("Ball position:", ballNode.position)
            event.accepted = true
        }

        Component.onCompleted: {
            forceActiveFocus()  // 启动时确保焦点
            console.log("InputHandler focus:", activeFocus)
        }
    }

    // 禁用物理输入（保留原代码）
    Item {
        id: inputItem
        visible: false
        anchors.fill: parent
        Keys.onPressed: (event) => { }
        property real speed: 1000000000
    }

    View3D {
        id: view3D
        anchors.fill: parent
        environment: SceneEnvironment {
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // 主光源
        PointLight {
            position: Qt.vector3d(400, 1200, 0)
            color: "#FFFFFF"
            ambientColor: "#202020"
            brightness: 200
            castsShadow: true
            shadowFactor: 50
            shadowMapQuality: Light.ShadowMapQualityHigh
        }

        // 相机
        Node {
            id: originNode
            PerspectiveCamera {
                id: viewCamera
                position: Qt.vector3d(0, 1700, 1400)
                eulerRotation.x: -50
            }
        }
        camera: viewCamera

        // OrbitCameraController
        OrbitCameraController {
            id: orbitController
            anchors.fill: parent
            origin: originNode
            camera: viewCamera
            mouseEnabled: false
            panEnabled: true
            xSpeed: 0.2
            ySpeed: 0.2
            yInvert: true
        }

        // MouseArea：左键拖拽控制视角
        MouseArea {
            anchors.fill: parent
            z: 1000
            acceptedButtons: Qt.LeftButton
            focus: false  // 不窃取键盘焦点
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    orbitController.mouseEnabled = true
                    console.log("Mouse pressed: Left button")
                }
            }
            onReleased: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    orbitController.mouseEnabled = false
                    inputHandler.forceActiveFocus()  // 释放后恢复键盘焦点
                    console.log("Mouse released: Left button")
                }
            }
        }

        // 球体
        Node {
            id: ballNode
            position: Qt.vector3d(0, 50, 0)
            Model {
                id: ballModel
                source: "#Sphere"
                scale: Qt.vector3d(0.8, 0.8, 0.8)
                materials: DefaultMaterial {
                    diffuseColor: "yellow"
                }
            }
            PointLight {
                position: Qt.vector3d(0, 50, 0)
                color: "red"
                brightness: 10
                castsShadow: false
            }
        }

        // 地面
        Node {
            Model {
                source: "#Rectangle"

                scale: Qt.vector3d(20, 20, 1)
                eulerRotation.x: -90
                materials: DefaultMaterial {
                    diffuseColor: "#808080"
                }
            }
        }
    }

}
