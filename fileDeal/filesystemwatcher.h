#ifndef FILESYSTEMWATCHER_H
#define FILESYSTEMWATCHER_H

#include <QObject>
#include <QFileSystemWatcher>
#include <QDir>
#include <QThread>

class FileSystemWatcher : public QObject
{
    Q_OBJECT
public:
    explicit FileSystemWatcher(QObject *parent = nullptr);

private:
    QString m_filePath = "/tmp/upgrade.log";
    QFileSystemWatcher *m_pFileWatcher;
    QThread *m_thread;
    void init();

signals:
    void reloadFile(QString filePath);//重新加载文件

private slots:
    void slotFileChanged();
};

#endif // FILESYSTEMWATCHER_H
