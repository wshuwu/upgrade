#ifndef COMMON_H
#define COMMON_H

#include <QString>

int getFiles(const QString& dirName, QString attributes, QStringList &fileList);//获取文件夹中所有attributes属性的文件名
bool isFileExist(QString fullFileName);   //判断文件是不是存在
void setStyle(const QString &style);//设置样式表

#endif // COMMON_H
