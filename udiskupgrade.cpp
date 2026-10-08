#include "udiskupgrade.h"
#include "ui_udiskupgrade.h"
#include "utils/common.h"
#include <QDebug>
#include <QFileDialog>
#include <QDateTime>
#include <QMessageBox>

static int SEL_LANG = 1;
const int LEFTLOG_MAX_ROWS_SHOW = 1000;


Udiskupgrade::Udiskupgrade(QWidget *parent)
    : QWidget(parent)
    , ui(new Ui::Udiskupgrade)
{
    ui->setupUi(this);
    ui->comboBox->setStyleSheet("QComboBox{font-size:25px;border-radius:2px;"
                                "padding:2px;}QComboBox::item{height:40px;"
                                "line-height:40px;padding:2px;}");

    init();
}

Udiskupgrade::~Udiskupgrade()
{
    m_process->close();
    m_process->deleteLater();
    m_process = nullptr;

    delete ui;
}

void Udiskupgrade::init()
{    
    resetLang2();

 	//创建保存日志的文件log.txt，如果已经存在则清空log.txt
    m_logFile = new QFile(m_logPath,this);
    m_logFile->open(QIODevice::Append);
    if(!m_logFile->isOpen()){
        delete  m_logFile;
        m_logFile = nullptr;
    }

    QString tip = "当前日志路径(Current log path)：" + m_logPath;
    ui->savelog_checkBox->setToolTip(tip);

    //升级包文件
    QStringList fileList;
    QString attribute = "*.tar.gz";
    if(getFiles(m_packageDirPath, attribute, fileList) == 0)
    {
        if(fileList.count() != 1)
        {
            ui->startUpgradeBtn->setEnabled(false);
            QString err = "升级包文件数量错误！只允许放1个安装包，请检查！";
            if(SEL_LANG) {
                err += "(The number of upgrade package files is incorrect! Only one installation package is allowed. Please check!)";
            }
            printLog(err, true);
            return;
        }
        else
        {
            ui->startUpgradeBtn->setEnabled(true);
            QString packageName = fileList.at(0);
            ui->package_lineEdit->setText(packageName);
        }
    }

    //进程间交互
    m_process = new QProcess(this);
    connect(m_process, &QProcess::readyReadStandardOutput, this ,&Udiskupgrade::readoutput);
    connect(m_process, &QProcess::readyReadStandardError, this ,&Udiskupgrade::readerror);

    //启动终端
    m_process->start("bash");                      //启动终端(Windows下改为cmd)
    m_process->waitForStarted();                   //等待启动完成

    //监听/tmp/upgrade.log文件并显示在升级进度中
    fileWatcher = new FileSystemWatcher;
    connect(fileWatcher, &FileSystemWatcher::reloadFile, this, &Udiskupgrade::showUpgradeLog);

    //定时器
    tmr = new QTimer(this);
    connect(tmr, &QTimer::timeout, this, &Udiskupgrade::startUpgradeSlot);

    m_topTimer = new QTimer(this);
    connect(m_topTimer,&QTimer::timeout, this,&Udiskupgrade::onTopHintTimeOut);
    m_topTimer->setInterval(1500);
    m_topTimer->start();

   //开始升级（打开软件，定时CNT_TIMEs后自动开始升级）
   on_startUpgradeBtn_clicked();

    m_checkUdisk = new CheckUdisk();
    connect(this, &Udiskupgrade::checkUDiskRemove, m_checkUdisk, &CheckUdisk::checkUDiskRemove);
    connect(m_checkUdisk, &CheckUdisk::udiskRemoved, this, &Udiskupgrade::uDiskRemovedSlot);
    connect(m_checkUdisk, &CheckUdisk::udiskExist, this, [=](){
        emit checkUDiskRemove();
    });
    ui->log_textBrowser->document()->setMaximumBlockCount(LEFTLOG_MAX_ROWS_SHOW);
    // QTimer::singleShot(1000,this,SLOT(ini_tip()));
}

void Udiskupgrade::resetLang()
{
    if(SEL_LANG) {
        ui->label->setText(tr("Upgrade Package: "));
        ui->startUpgradeBtn->setText(tr("Upgrade"));
        ui->cancelUpgradeBtn->setText(tr("Cancel Upgrade"));
        ui->resetBtn->setText(tr("System Restore"));
        ui->savelog_checkBox->setText(tr("Save Log"));
        ui->rebootBtn->setText(tr("Restart System"));
        ui->groupBox->setTitle(tr("Log"));
        ui->groupBox_3->setTitle(tr("Upgrade Information"));
    } else {
        ui->label->setText(tr("升级包："));
        ui->startUpgradeBtn->setText(tr("升级"));
        ui->cancelUpgradeBtn->setText(tr("取消升级"));
        ui->resetBtn->setText(tr("系统还原"));
        ui->savelog_checkBox->setText(tr("保存日志"));
        ui->rebootBtn->setText(tr("重启系统"));
        ui->groupBox->setTitle(tr("日志"));
        ui->groupBox_3->setTitle(tr("升级信息"));
    }

    QString tip = "当前日志路径：" + m_logPath;
    if(SEL_LANG) {
        tip = "Current log path: " + m_logPath;
    }
    ui->savelog_checkBox->setToolTip(tip);

    QStringList fileList;
    QString attribute = "*.tar.gz";
    if(getFiles(m_packageDirPath, attribute, fileList) == 0)
    {
        if(fileList.count() != 1)
        {
            ui->startUpgradeBtn->setEnabled(false);
            QString err = "升级包文件数量错误！只允许放1个安装包，请检查！";
            if(SEL_LANG) {
                err = "The number of upgrade package files is incorrect! Only one installation package is allowed. Please check!";
            }
            printLog(err, true);
            return;
        }
    }
}

void Udiskupgrade::resetLang2()
{
    ui->comboBox->hide();
    ui->label->setText(tr("升级包(Upgrade Package)："));
    ui->startUpgradeBtn->setText(tr("升  级\nUpgrade"));
    ui->cancelUpgradeBtn->setText(tr("取消升级\nCancel"));
    ui->resetBtn->setText(tr("系统还原\nReset"));
    ui->savelog_checkBox->setText(tr("保存日志(Save Log)"));
    ui->rebootBtn->setText(tr("重启系统\nRestart System"));
    ui->groupBox->setTitle(tr("日志(Log)"));
    ui->groupBox_3->setTitle(tr("升级信息(Upgrade Information)"));
    ui->label_tip->setStyleSheet("QLabel#label_tip{font-size:18px;border-radius:2px;padding:2px;color:gray;}");
    QString tips = "若需要清理项目应用程序时，先点击【系统还原】后再升级。\n"
                  "If you need to clear the project application,click【Reset】before upgrading.";
    ui->label_tip->setText(tips);
}

void Udiskupgrade::ini_tip()
{
    tmr->stop();
    tmrTriggerCnt = 0;
    ui->lcdNumber->display(CNT_TIME);
    ui->startUpgradeBtn->setEnabled(true);
    ui->cancelUpgradeBtn->setDisabled(true);

    QString tip = "如需要清理项目应用程序时，先点击【系统还原】后再升级，否则直接升级。\n"
                  "If you need to clear the project application, click [System Restore] before upgrading; otherwise, upgrade directly.";
    QMessageBox::information(this, "Tip", tip);
    on_startUpgradeBtn_clicked();
}


//开始升级
void Udiskupgrade::on_startUpgradeBtn_clicked()
{
    ui->startUpgradeBtn->setDisabled(true);
    ui->rebootBtn->setDisabled(true);
    m_udiskRemoved = false;

    //判断install.sh文件是否存在
    qDebug() << "m_installSH_filepath=" << m_installSH_filepath;
    if(!isFileExist(m_installSH_filepath))
    {
        QString err = "install.sh文件不存在！请检查！";
        if(SEL_LANG) {
            err += "(The install.sh file does not exist! Please check!)";
        }
        printLog(err, true);
        return;
    }

    //重置倒计时为CNT_TIMEs
    ui->lcdNumber->display(CNT_TIME);

    //打印开始升级日志
    QString msg = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss ");
    msg += QString("开始升级！你有%1s时间可以取消升级。").arg(CNT_TIME);
    msg += QString("(Upgrade in progress! You have %1 second to cancel the upgrade.)").arg(CNT_TIME);

    printLog(msg, false);

    //取消升级可点击
    ui->cancelUpgradeBtn->setEnabled(true);

    //开始倒计时，每隔1s触发
    tmrTriggerCnt = 0;
    tmr->start(1000);
}


void Udiskupgrade::startUpgradeSlot()
{
    tmrTriggerCnt++;

    //更新倒计时显示
    ui->lcdNumber->display(CNT_TIME - tmrTriggerCnt);

    if(tmrTriggerCnt == CNT_TIME)
    {
        //停止计时
        tmr->stop();
        tmrTriggerCnt = 0;

        //禁止点击取消升级和系统复位
        ui->cancelUpgradeBtn->setDisabled(true);
        
        ui->resetBtn->setDisabled(true);

        //向终端写入命令，注意尾部的“\n”不可省略
        const QByteArray shellCmd = "sh " + m_installSH_filepath.toUtf8() + "\n";
        m_process->write(shellCmd);
    }
}

//打印并保存日志
void Udiskupgrade::printLog(QString msg, bool isErr)
{
    QString log;

    //改变字体颜色：错误信息打印红色，正确信息打印绿色
    if(isErr)
    {
        log = ">> ERROR:" + msg;
        ui->log_textBrowser->setTextColor(Qt::red);
    }
    else
    {
        log =  ">> " + msg;
        ui->log_textBrowser->setTextColor(Qt::black);
    }

    if(msg.contains("开始升级") || msg.contains("将自动重启系统") ||
            msg.contains("Upgrade in progress") || msg.contains("The system will automatically restart"))
    {
        ui->log_textBrowser->setTextColor(Qt::green);
    }
    ui->log_textBrowser->append(log);

    //保存日志
    saveLog(log);
}

//打印cmd输出日志
void Udiskupgrade::readoutput()
{
    QString msg = m_process->readAllStandardOutput().data();
    printLog(msg, false);
}

//打印cmd输出错误
void Udiskupgrade::readerror()
{
    QString err = m_process->readAllStandardError().data();
    printLog(err, true);
}

void Udiskupgrade::saveLog(QString log)
{
    if(ui->savelog_checkBox->isChecked())
    {
        if(m_logFile){
            QString msg = log + "\n";
            m_logFile->write(msg.toUtf8().data());
        }
    }
}

//显示/tmp/upgrade.log
void Udiskupgrade::showUpgradeLog(QString filePath)
{
    try{
        QFile file(filePath);
        if (!file.exists()) {
            QString err = "/tmp/upgrade.log文件不存在！";
            if(SEL_LANG) {
                err += "(The file /tmp/upgrade.log does not exist!)";
            }
            throw(err);
        }
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString err = "/tmp/upgrade.log文件打开失败！";
            if(SEL_LANG) {
                err += "(Failed to open the /tmp/upgrade.log file!)";
            }
            throw(err);
        }

        ui->upgrade_textBrowser->clear();
        QTextStream in(&file);
        while (!in.atEnd()) {
            //显示/tmp/upgrade.log内容
            QString upgradeLog = in.readAll().toUtf8();
            ui->upgrade_textBrowser->setText(upgradeLog);

            //检测升级结束
            if(upgradeLog.contains("即将进行系统重启") ||
                    upgradeLog.contains("System restart is imminent"))
            {
                ui->startUpgradeBtn->setEnabled(true);

                //打印等待重启系统日志
                QString msg = "软件升级已完成，请拔出U盘。拔出U盘后，将自动重启系统！";
                if(SEL_LANG) {
                    msg += "(The software upgrade is complete. Please remove the USB drive. The system will automatically restart after the USB drive is removed!)";
                }
                printLog(msg, false);

                //系统重启按钮可点击
                ui->rebootBtn->setEnabled(true);

                //检测U盘是否拔出
                emit checkUDiskRemove();
            }
        }

        file.close();

    }catch(QString err)
    {
        printLog(err, true);
        return;
    }
}

void Udiskupgrade::on_cancelUpgradeBtn_clicked()
{
    //停止计时
    tmr->stop();
    tmrTriggerCnt = 0;

    //重置倒计时为CNT_TIMEs
    ui->lcdNumber->display(CNT_TIME);

    ui->startUpgradeBtn->setEnabled(true);
    ui->cancelUpgradeBtn->setDisabled(true);

    //打印开始升级日志
    QString msg = "取消升级成功！";
    msg += "(Upgrade cancelled successfully!)";
    printLog(msg, false);
}


void Udiskupgrade::on_rebootBtn_clicked()
{
    if(m_udiskRemoved) //U盘已拔出
    {
        m_udiskRemoved = false;
        QString s1 = tr("重启系统"), s2 = tr("重启系统前，请先确定U盘已拔出！\n如果U盘已拔出，请点击Yes将重启系统\n点击No将放弃重启系统。");
        if(SEL_LANG) {
            s1 += "(Restart the system)";
            s2 += "\nBefore restarting the system, please make sure the USB drive has been removed!\n"
                 "If the USB drive has been removed, please click Yes to restart the system; \n"
                 "otherwise, click No to abandon the system restart.";
        }
        int ok = QMessageBox::question(this, s1,
                                       s2,
                                       QMessageBox::Yes|QMessageBox::No, QMessageBox::No);
        if(ok == QMessageBox::Yes)
        {
            system("reboot");
        }
    }
    else  //U盘未拔出
    {        
//        if(!SEL_LANG) {
//            QMessageBox::warning(this, "警告", "检测到U盘未拔出！\n重启系统前，需要先拔出U盘！");
//        } else {
//            QMessageBox::warning(this, "Warn",
//                                 "USB drive detected as not being removed! \nPlease remove the USB drive before restarting the system!");
//        }

        QMessageBox::warning(this, "警告(Warn)", "检测到U盘未拔出！\n重启系统前，需要先拔出U盘！\n"
                                               "USB drive detected as not being removed! \nPlease remove the USB drive before restarting the system!");
    }

}

//检测到U盘已拔出
void Udiskupgrade::uDiskRemovedSlot()
{
    m_udiskRemoved = true;

    //打印重启系统日志
    QString msg = "检测到U盘已拔出，即将自动重启系统！";
    if(SEL_LANG) {
        msg += "(USB drive detected as removed. The system will restart automatically soon!)";
    }
    printLog(msg, false);

    //自动重启系统
    system("reboot");
}

void Udiskupgrade::on_resetBtn_clicked()
{
    ui->resetBtn->setEnabled(false);
    if (tmr->isActive()) {
        tmr->stop();
    }
    if(SEL_LANG) {
        m_process->write("echo \"Execute recovery...\";\nrecovery reset;\nsleep 5;\n");
    } else {
        m_process->write("echo \"执行recovery...\";\nrecovery reset;\nsleep 5;\n");
    }
}
void Udiskupgrade::onTopHintTimeOut()
{
    // activeWindow
    if(!isActiveWindow()){
        raise();
        activateWindow();
    }
}


void Udiskupgrade::on_comboBox_currentIndexChanged(int index)
{
    SEL_LANG = index;
    resetLang();
}
