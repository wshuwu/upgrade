#ifndef CHECKUDISK_H
#define CHECKUDISK_H

#include <QThread>
#include <QObject>

class CheckUdisk : public QThread
{
    Q_OBJECT
public:
    CheckUdisk();
public slots:
    bool checkUDiskRemove();
private:
    QThread *m_thread;
signals:
    void udiskRemoved();
    void udiskExist();
};

#endif // CHECKUDISK_H
