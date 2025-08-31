#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTcpSocket>
#include <QTimer>
#include <QDataStream>
#include <QDebug>
#include "ngx_c_crc32.h"

// 定义结构（与服务器一致）
struct STRUCT_PLAYER {
    int x;
    int y;
    int score;
};

struct STRUCT_BEAN {
    int x;
    int y;
};

struct STRUCT_STATE {
    STRUCT_PLAYER player;
    int bean_count;
    int other_player_count; // 新增：其他玩家数量
    // 后跟 bean_count 个 STRUCT_BEAN + other_player_count 个 STRUCT_PLAYER
};

struct STRUCT_MOVE {
    int x;
    int y;
};

struct STRUCT_EAT_BEAN {
    int bean_x;
    int bean_y;
};

// 定义 msgCode
const unsigned short CMD_JOIN = 1;
const unsigned short CMD_MOVE = 2;
const unsigned short CMD_EAT_BEAN = 3;
const unsigned short CMD_GET_STATE = 4;
const unsigned short CMD_STATE = 5;

// 包头
struct COMM_PKG_HEADER {
    unsigned short pkgLen;
    unsigned short msgCode;
    int crc32;
};
const int PKG_HEADER_LEN = sizeof(COMM_PKG_HEADER);

class GameClient : public QObject {
    Q_OBJECT
public:
    GameClient(QQmlApplicationEngine* engine) : m_engine(engine), m_receiveBuffer() {
        m_socket = new QTcpSocket(this);
        connect(m_socket, &QTcpSocket::connected, this, &GameClient::onConnected);
        connect(m_socket, &QTcpSocket::readyRead, this, &GameClient::onReadyRead);
        m_socket->connectToHost("127.0.0.1", 81);

        QTimer* timer = new QTimer(this);
        connect(timer, &QTimer::timeout, this, &GameClient::requestState);
        timer->start(10); // 恢复到100ms，优化多人同步
    }

signals:
    void updatePlayer(int x, int y, int score);
    void updateOtherPlayers(const QVariantList& otherPlayers); // 新增信号：其他玩家
    void updateBeans(const QVariantList& beans);

public slots:
    void sendJoin() {
        sendPacket(CMD_JOIN, nullptr, 0);
    }

    void sendMove(int x, int y) {
        QByteArray body;
        QDataStream bodyStream(&body, QIODevice::WriteOnly);
        bodyStream.setByteOrder(QDataStream::BigEndian);
        bodyStream << x << y;
        sendPacket(CMD_MOVE, body.constData(), body.size());
    }

    void sendEatBean(int beanX, int beanY) {
        QByteArray body;
        QDataStream bodyStream(&body, QIODevice::WriteOnly);
        bodyStream.setByteOrder(QDataStream::BigEndian);
        bodyStream << beanX << beanY;
        sendPacket(CMD_EAT_BEAN, body.constData(), body.size());
    }

    void requestState() {
        sendPacket(CMD_GET_STATE, nullptr, 0);
    }

private slots:
    void onConnected() {
        qDebug() << "Connected to server";
        sendJoin(); // 连接后加入游戏
    }

    void onReadyRead() {
        m_receiveBuffer.append(m_socket->readAll());

        while (m_receiveBuffer.size() >= PKG_HEADER_LEN) {
            QDataStream stream(m_receiveBuffer);
            stream.setByteOrder(QDataStream::BigEndian);
            unsigned short pkgLen;
            unsigned short msgCode;
            int crc32Received;
            stream >> pkgLen >> msgCode >> crc32Received;
            if (m_receiveBuffer.size() < pkgLen) {
                break;
            }
            QByteArray packet = m_receiveBuffer.left(pkgLen);
            m_receiveBuffer.remove(0, pkgLen);
            QByteArray body = packet.mid(PKG_HEADER_LEN);
            CCRC32 *crc32Instance = CCRC32::GetInstance();
            int crc32Calculated = crc32Instance->Get_CRC(reinterpret_cast<unsigned char *>(body.data()), body.size());
            if (crc32Calculated != crc32Received) {
                qDebug() << "CRC32 validation failed! Calculated:" << crc32Calculated << "Received:" << crc32Received;
                continue;
            }

            if (msgCode == CMD_STATE) {
                handleState(body);
            }
        }
    }

private:
    void sendPacket(unsigned short msgCode, const char* pBody, int bodyLen) {
        QByteArray bodyData(pBody, bodyLen);
        int totalLen = PKG_HEADER_LEN + bodyLen;
        QByteArray packet;
        QDataStream stream(&packet, QIODevice::WriteOnly);
        stream.setByteOrder(QDataStream::BigEndian);
        CCRC32 *crc32Instance = CCRC32::GetInstance();
        int crc = (bodyLen > 0) ? crc32Instance->Get_CRC(reinterpret_cast<unsigned char *>(bodyData.data()), bodyLen) : 0;
        stream << static_cast<unsigned short>(totalLen) << msgCode << crc;
        packet.append(bodyData);
        m_socket->write(packet);
    }

    void handleState(const QByteArray& body) {
        if (body.size() < sizeof(int)*5) return; // 更新最小大小，包含 other_player_count

        QDataStream bodyStream(body);
        bodyStream.setByteOrder(QDataStream::BigEndian);

        int x, y, score, bean_count, other_player_count;
        bodyStream >> x >> y >> score >> bean_count >> other_player_count;

        QVariantList beanList;
        for (int i = 0; i < bean_count; ++i) {
            int bx, by;
            bodyStream >> bx >> by;
            beanList.append(QVariantMap{ {"x", bx}, {"y", by} });
        }

        QVariantList otherPlayerList;
        for (int i = 0; i < other_player_count; ++i) {
            int ox, oy, os;
            bodyStream >> ox >> oy >> os;
            otherPlayerList.append(QVariantMap{ {"x", ox}, {"y", oy}, {"score", os} });
        }

        emit updatePlayer(x, y, score);
        emit updateBeans(beanList);
        emit updateOtherPlayers(otherPlayerList); // 新增信号触发
    }

    QTcpSocket* m_socket;
    QQmlApplicationEngine* m_engine;
    QByteArray m_receiveBuffer;
};

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    GameClient client(&engine);
    engine.rootContext()->setContextProperty("gameClient", &client);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("pacman", "Main");
    return app.exec();
}
#include "main.moc"
