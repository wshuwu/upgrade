#include "checkudisk.h"
#include <QProcess>

CheckUdisk::CheckUdisk()
{
    m_thread = new QThread();    //创建数据解析线程
    this->moveToThread(m_thread);//将当前对象加入线程
    m_thread->start();           //开启线程

}

bool CheckUdisk::checkUDiskRemove()
{
   QProcess piTerminal;
   piTerminal.start("sh",QStringList()<<"-c"<<"lsblk|grep media|grep part|grep -o -E '/.*'");
   piTerminal.waitForFinished();
   QString ret = piTerminal.readAllStandardOutput();
   QStringList list = ret.split("\n");
   if(list.size() != 1) //检测到U盘
   {
       emit udiskExist();
   }
   if(list.size() == 1) //未检测到U盘
   {
       emit udiskRemoved();
   }
   return true;
}
