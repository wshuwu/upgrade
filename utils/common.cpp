#include "utils/common.h"
#include <QDir>
#include <QApplication>

//获取文件夹中所有attributes属性的文件名
int getFiles(const QString& dirName, QString attributes, QStringList &fileList)
{
    QDir* dirinfo = new QDir(dirName);
    if (!dirinfo->exists()) {
        delete dirinfo, dirinfo = nullptr;
        return -1;
    }
    dirinfo->setNameFilters(QStringList(attributes));
    fileList.clear();
    fileList = dirinfo->entryList(QDir::Files);
    fileList.removeOne(".");
    fileList.removeOne("..");

    delete dirinfo;
    dirinfo = nullptr;
    return 0;
}

//判断文件是不是存在
bool isFileExist(QString fullFileName)//fullFileName是文件全路径(包含文件名)
{
    QFileInfo fileInfo(fullFileName);
    if(fileInfo.isFile())
    {
        return true;
    }

    return false;
}

//设置样式表
void setStyle(const QString &style)
{
    QFile qss(style);
    qss.open(QFile::ReadOnly);
    qApp->setStyleSheet(qss.readAll());
    qss.close();
}
