import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    visible: true
    width: 500
    height: 500
    title: "Pacman Client"

    property int playerX: 0
    property int playerY: 0
    property int score: 0

    Connections {
        target: gameClient
        function onUpdatePlayer(x, y, s) {
            console.log("onUpdatePlayer: x =", x, "y =", y, "score =", s)
            playerX = x
            playerY = y
            score = s
        }
        function onUpdateBeans(beans) {
            beanModel.clear()
            for (var i = 0; i < beans.length; i++) {
                beanModel.append({x: beans[i].x, y: beans[i].y})
            }
        }
    }

    Rectangle {
        id: grid
        anchors.fill: parent
        color: "black"

        Repeater { model: 11; Rectangle { x: 0; y: index * 50; width: 500; height: 1; color: "gray" } }
        Repeater { model: 11; Rectangle { x: index * 50; y: 0; width: 1; height: 500; color: "gray" } }

        ListModel { id: beanModel }
        Repeater {
            model: beanModel
            Rectangle {
                x: model.x * 50 + 22.5
                y: model.y * 50 + 22.5
                width: 5; height: 5
                color: "yellow"
            }
        }

        Rectangle {
            id: player
            x: playerX * 50 + 15
            y: playerY * 50 + 15
            width: 20; height: 20
            color: "blue"
            radius: 10
            focus: true

            Keys.onPressed: (event) => {
                            var newX = playerX
                            var newY = playerY
                            if (event.key === Qt.Key_W || event.key === Qt.Key_Up)    { if (playerY > 0) newY--; }
                            if (event.key === Qt.Key_S || event.key === Qt.Key_Down)  { if (playerY < 9) newY++; }
                            if (event.key === Qt.Key_A || event.key === Qt.Key_Left)  { if (playerX > 0) newX--; }
                            if (event.key === Qt.Key_D || event.key === Qt.Key_Right) { if (playerX < 9) newX++; }
                            if (newX !== playerX || newY !== playerY) {
                                console.log("Sending move: x =", newX, "y =", newY)
                                gameClient.sendMove(newX, newY) // 只发送请求，不直接修改
                            }
                            event.accepted = true
            }
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            text: "Score: " + score
            color: "red"
            font.pixelSize: 30
            z: 10
            onTextChanged: console.log("Score Text changed to:", text)
        }
    }

    // 移除本地 checkCollisions 和 bean 生成，依赖服务器
}
