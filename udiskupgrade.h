#ifndef UDISKUPGRADE_H
#define UDISKUPGRADE_H

#include "fileDeal/filesystemwatcher.h"
#include "checkUdisk/checkudisk.h"
#include <QWidget>
#include <QDir>
#include <QProcess>
#include <QCoreApplication>
#include <QTimer>

QT_BEGIN_NAMESPACE
namespace Ui { class Udiskupgrade; }
QT_END_NAMESPACE

#define CNT_TIME 10
class Udiskupgrade : public QWidget
{
    Q_OBJECT

public:
    Udiskupgrade(QWidget *parent = nullptr);
    ~Udiskupgrade();

private slots:
    void on_startUpgradeBtn_clicked();

    void readoutput();
    void readerror();
    void ini_tip();

    void showUpgradeLog(QString filePath);
    void startUpgradeSlot();

    void on_cancelUpgradeBtn_clicked();

    void on_rebootBtn_clicked();

    void uDiskRemovedSlot();
    void on_resetBtn_clicked();

    void onTopHintTimeOut();
    void on_comboBox_currentIndexChanged(int index);

private:
    Ui::Udiskupgrade *ui;

    //要用QDir::currentPath，不能用QCoreApplication::applicationDirPath()-可执行程序在开发板中是/tmp路径
    QString m_upgradePath = QDir::currentPath();
    QString m_packageDirPath = QDir::currentPath();
    QString m_packagePath;
    QProcess *m_process;
    QString m_installSH_filepath = QDir::currentPath() + "/install.sh";
    QString m_logPath = QDir::currentPath() + "/log.txt";
    QFile *m_logFile;
    FileSystemWatcher *fileWatcher;
    QString m_filePath = "/tmp/upgrade.log";
    QTimer *tmr;//定时器
    QTimer *m_topTimer;
    int tmrTriggerCnt;//定时器触发次数
    CheckUdisk *m_checkUdisk;
    bool m_udiskRemoved = false;

    void init();
    void resetLang();
    void resetLang2();
    void printLog(QString msg, bool isErr);
    void saveLog(QString log);
signals:
    void checkUDiskRemove();
};
#endif // UDISKUPGRADE_H
