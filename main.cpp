#include "udiskupgrade.h"
#include "utils/common.h"
#include <QApplication>
#include <QStyleFactory>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);

    QApplication::setStyle(QStyleFactory::create("fusion"));
    setStyle(":/qss/qss/blue.qss");

    Udiskupgrade w;
    w.setWindowFlags(w.windowFlags() | Qt::WindowStaysOnTopHint);
    w.showFullScreen();
//    w.showMaximized();
    return a.exec();
}
