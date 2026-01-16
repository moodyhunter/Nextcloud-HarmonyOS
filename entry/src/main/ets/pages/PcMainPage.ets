import {
    Account,
    DirectoryEntry,
    DownloadFile,
    ListFiles,
    Logger,
    Nextcloud,
    SyncConfiguration,
    SyncFolderManager,
    TransferManager,
    TransferManagerImpl,
    TransferTask,
} from 'nextcloud';
import { common } from '@kit.AbilityKit';
import { fileIo, fileShare, fileUri, picker } from '@kit.CoreFileKit';
import * as CloudSyncApi from '../utils/CloudSyncApi';
import { PermissionManager } from '../utils/PermissionManager';
import { LengthMetrics } from '@kit.ArkUI';
import { DownloadQueue } from '../utils/DownloadQueue';
import { SettingsPage } from './SettingsPage';

const TAG = 'PcAbility'
const OPERATION_MODES = fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE;

@ComponentV2
struct TransferProgressItem {
    @Require @Param transferTask: TransferTask;

    build() {
        Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Center, space: { main: LengthMetrics.vp(8) } }) {
            Text(this.transferTask.filename)
                .width(180)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.End)

            Progress({
                value: this.transferTask.transferredSize,
                total: this.transferTask.totalSize,
            })

            Text(this.transferTask.progressPercentText)
                .width(100)
        }
    }
}

@ComponentV2
struct SyncConfigurationRow {
    @Require @Param readonly syncFolderManager: SyncFolderManager;
    @Require @Param readonly configuration: SyncConfiguration;
    @Require @Param readonly account: Account;
    private downloadQueue: DownloadQueue = new DownloadQueue();

    build() {
        Row({ space: 8 }) {
            Text(`${this.configuration.id} : ${this.configuration.localFolder.localPath} <=> ${this.configuration.remoteFolder.remotePath}`)

            Blank()
                .flexGrow(1)

            Button('connect')
                .onClick(async () => {
                    CloudSyncApi.connect(this.configuration.localFolder.localPath);
                })

            Button('disconnect')
                .onClick(() => {
                    CloudSyncApi.disconnect(this.configuration.localFolder.localPath);
                })

            Button('sync all')
                .onClick(() => this.doDownloadAll())

            Button('DELETE')
                .onClick(async () => {
                    CloudSyncApi.disconnect(this.configuration.localFolder.localPath);
                    CloudSyncApi.remove(this.configuration.localFolder.localPath);
                    await this.syncFolderManager.removeSyncConfiguration(this.configuration);
                })
        }
        .width('100%')
        .height(50)
        .padding({ left: 8, right: 8 })
        .border({ width: 1, color: Color.Green })
    }

    private async doDownloadAll() {
        Logger.Info(TAG, `sync all`);
        this.downloadQueue.addRootDir(this.account);
        while (this.downloadQueue.hasPendingItem()) {
            let next = await this.downloadQueue.getNextDownloadFile();
            if (next === undefined) {
                break;
            }
            Logger.Info(TAG, next.relativePath);
            if (next.isDirectory) {
                try {
                    fileIo.mkdirSync(this.configuration.localFolder.localPath + '/' + next.relativePath);
                } catch (e) {
                }
            } else {
                await DownloadFile(this.account, next.relativePath, this.configuration.localFolder.localPath + '/' + next.relativePath);
            }
            Logger.Info(TAG, next.relativePath);
        }
        Logger.Info(TAG, `download completed`);
    }
}

@Entry
@ComponentV2
struct PCAbility {
    @Local private readonly activeAccountId: number = 0; // TODO: get from PersistentStorage
    @Local private readonly account: Account = Nextcloud.getAccountById(this.activeAccountId);
    @Local private opHistory: CloudSyncApi.FileChangeInfo[] = [];
    @Local private files: DirectoryEntry[] = [];
    @Local private syncFolderManager: SyncFolderManager = Nextcloud.getSyncFolderManager();
    @Local private transferManager: TransferManagerImpl = TransferManager;
    private pendingMoveTo: Map<string, string> = new Map();

    @Builder
    pathOps() {
        Column() {
            List({ space: 4 }) {
                ListItem() {
                    Button('+')
                        .onClick(async () => {
                            await this.doAddNewSyncConfiguration();
                        })
                        .width('100%')
                }

                ForEach(Array.from(this.syncFolderManager.allSyncConfigurations), (conf: [number, SyncConfiguration], index: number) => {
                    ListItem() {
                        SyncConfigurationRow({
                            account: this.account,
                            syncFolderManager: this.syncFolderManager,
                            configuration: conf[1],
                        })
                    }
                    .clip(true)
                })
            }
            .width('100%')
            .height('100%')
        }
        .width('100%')
        .height('100%')
        .padding(16)
    }

    @Builder
    pcMainPage() {
        Column({ space: 16 }) {
            Column({ space: 8 }) {
                List() {
                    ForEach(this.files, (item: DirectoryEntry, index: number) => {
                        ListItem() {
                            Text(`${index}: ${item.name} --- ${item.isDirectory ? 'dir' : item.mime}`)
                        }
                        .clip(true)
                    })
                }
                .width('100%')
                .height(150)

                Button('reload')
                    .onClick(async () => {
                        this.files = await ListFiles(this.account, '/');
                    })

            }
            .padding(8)
            .width('100%')
            .backgroundColor($r('sys.color.glass_material_outline_secondary'))

            Column({ space: 8 }) {
                Text('download progress')

                List() {
                    LazyForEach(this.transferManager.tasks, (item: TransferTask) => {
                        ListItem() {
                            TransferProgressItem({
                                transferTask: item
                            })
                        }
                    })
                }
                .width('100%')
                .height(250)
            }

            Column({ space: 8 }) {
                Text('Operation History:')
                List() {
                    ForEach(this.opHistory, (item: CloudSyncApi.FileChangeInfo, index) => {
                        ListItem() {
                            Row() {
                                Text(`${index + 1}. `)
                                Text(
                                    `: ${item.relativePath}, Op: ${CloudSyncApi.FileChangeOperationType[item.operationType]}`
                                )
                            }
                        }
                    })
                }
                .width('100%')
                .height(250)
            }
            .padding(8)
            .backgroundColor($r('sys.color.glass_material_outline_secondary'))
        }
        .width('100%')
        .height('100%')
        .padding(16)
    }

    async aboutToAppear(): Promise<void> {
        Logger.Info(TAG, `pcAbility aboutToAppear`);
        await PermissionManager.RequestPermission(this.getUIContext(), ["ohos.permission.FILE_ACCESS_PERSIST"])
        for (let syncConfiguration of this.syncFolderManager.allSyncConfigurations.values()) {
            Logger.Info(TAG, `configuration: ${syncConfiguration.id} --- ${syncConfiguration.localFolder.localPath} <=> ${syncConfiguration.remoteFolder.remotePath}`);
            CloudSyncApi.connect(syncConfiguration.localFolder.localPath);

            try {
                await fileShare.activatePermission([{
                    uri: fileUri.getUriFromPath(syncConfiguration.localFolder.localPath),
                    operationMode: OPERATION_MODES
                }]);
                Logger.Info(TAG, `activate permission done for '${syncConfiguration.localFolder.localPath}'`);
            } catch (e) {
                Logger.Error(TAG, `failed to activate: ${JSON.stringify(e)}`);
            }
        }

        CloudSyncApi.registerFileChangeMonitor((info: CloudSyncApi.FileChangeInfo) => {
            this.onFileChanged(info)
        });

        this.files = await ListFiles(this.account, '/');
    }

    aboutToDisappear(): void {
        for (let syncConfiguration of this.syncFolderManager.allSyncConfigurations.values()) {
            CloudSyncApi.disconnect(syncConfiguration.localFolder.localPath);
        }
    }

    build() {
        Tabs({ barPosition: BarPosition.Start }) {
            TabContent() {
                this.pathOps()
            }
            .tabBar('Paths')

            TabContent() {
                this.pcMainPage()
            }
            .tabBar($r('app.string.tab_files'))

            TabContent() {
                SettingsPage({ currentAccount: this.account })
                    .width('100%')
                    .height('100%')
            }
            .tabBar($r('app.string.tab_settings'))
        }
        .vertical(true)
    }

    private async doAddNewSyncConfiguration() {
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        let documentPicker = new picker.DocumentViewPicker(context);
        let items = await documentPicker.select({
            defaultFilePathUri: 'file://docs/storage/Users/currentUser/CloudSyncFolder',
            maxSelectNumber: 1,
            selectMode: picker.DocumentSelectMode.FOLDER,
        });
        if (items.length !== 1) {
            Logger.Error(TAG, `???`);
            return;
        }
        let path = new fileUri.FileUri(items[0]).path;

        try {
            Logger.Info(TAG, items[0]);
            await fileShare.persistPermission([{
                uri: items[0],
                operationMode: OPERATION_MODES
            }]);
            Logger.Info(TAG, `persist done`);
        } catch (e) {
            Logger.Error(TAG, `failed to persist permission: ${JSON.stringify(e)}`);
        }

        let localPathAlias = 'LocalPathAlias_' + Date.now();
        let localFolder = await this.syncFolderManager.addLocalFolder(path, localPathAlias);
        Logger.Info(TAG, `added local folder: ${JSON.stringify(localFolder)}`);
        let remoteFolder = await this.syncFolderManager.addRemoteFolder(this.account, '/', 'RemotePathAlias_' + Date.now());
        Logger.Info(TAG, `added remote folder: ${JSON.stringify(remoteFolder)}`);
        let syncConfig = await this.syncFolderManager.addSyncConfiguration(localFolder, remoteFolder);
        Logger.Info(TAG, `added sync configuration: ${JSON.stringify(syncConfig)}`);
        let addResult: number = CloudSyncApi.add(localPathAlias, path);
        Logger.Info(TAG, `Add: ${addResult}`)
    }

    private async onFileChanged(info: CloudSyncApi.FileChangeInfo): Promise<void> {
        if (info.operationType === CloudSyncApi.FileChangeOperationType.MOVE_FROM) {
            this.pendingMoveTo.set(info.fileId, info.relativePath);
        } else if (info.operationType === CloudSyncApi.FileChangeOperationType.MOVE_TO) {
            let moveFrom = this.pendingMoveTo.get(info.fileId);
            if (moveFrom === undefined) {
                Logger.Error(TAG, `got a MoveTo without a MoveFrom`);
            } else {
                Logger.Info(TAG, `move: ${moveFrom} -> ${info.relativePath}`);
                this.pendingMoveTo.delete(info.fileId);
            }
        }
        Logger.Info(TAG, `${CloudSyncApi.FileChangeOperationType[info.operationType]} ::: '${info.relativePath}'`);
        this.opHistory = [info, ...this.opHistory];
    }
}
