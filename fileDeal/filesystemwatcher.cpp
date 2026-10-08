#include "filesystemwatcher.h"
#include <QFile>
#include <QDebug>
#include <QTextStream>

FileSystemWatcher::FileSystemWatcher(QObject *parent)
    : QObject{parent}
{
    m_thread = new QThread();    //创建数据解析线程
    this->moveToThread(m_thread);//将当前对象加入线程
    m_thread->start();           //开启线程

    init();
}

void FileSystemWatcher::init()
{
    //文件不存在，则新建
//    QString path = "E:/tmp/upgrade.log";
    QFile file(m_filePath);
    if (!file.open(QIODevice::ReadWrite | QIODevice::Text)) {
        qDebug() << "文件打开失败！";
    }

    //文件检测
    m_pFileWatcher = new QFileSystemWatcher();
    m_pFileWatcher->addPath(m_filePath);
    connect(m_pFileWatcher, &QFileSystemWatcher::fileChanged, this, &FileSystemWatcher::slotFileChanged);
}

//检测到文件被修改
void FileSystemWatcher::slotFileChanged()
{
    if (m_pFileWatcher->files().isEmpty())
    {
        qDebug() << "被检测的文件为空";
        return;
    }

    //触发重新加载文件
    emit reloadFile(m_filePath);
}


