import { DirectoryEntry, ListFiles, Logger, DownloadFile, Nextcloud, Account } from 'nextcloud';
import { common } from '@kit.AbilityKit';
import { fileIo, fileShare, fileUri, picker } from '@kit.CoreFileKit';
import { Constants } from '../utils/Common';
import * as CloudSyncApi from '../utils/CloudSyncApi';
import { PermissionManager } from '../utils/PermissionManager';
import { TransferManager, TransferManagerImpl, TransferTask } from 'nextcloud';
import { LengthMetrics } from '@kit.ArkUI';
import { DownloadQueue } from '../utils/DownloadQueue';

const TAG = 'PcAbility'
const OPERATION_MODES = fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE;

@Component
struct TransferProgressItem {
    @ObjectLink transferTask: TransferTask;

    build() {
        Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Center, space: { main: LengthMetrics.vp(8) } }) {
            Text(this.transferTask.filename)
                .width(180)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.End)

            Progress({
                value: this.transferTask.transferedSize,
                total: this.transferTask.totalSize,
            })

            Text(this.transferTask.progressPercentText)
                .width(100)
        }
    }
}


@Entry
@Component
struct PCAbility {
    @StorageLink(Constants.PC_CLOUD_DISK_PATH) private path: string = '';
    @StorageLink(Constants.PC_CLOUD_DISK_ALIAS) @Watch('onAliasChanged') private alias: string = 'Moody 的 Nextcloud';
    @State private opHistory: CloudSyncApi.FileChangeInfo[] = [];
    @State private files: DirectoryEntry[] = [];
    @StorageLink(Constants.PHONE_ACTIVE_ACCOUNT_ID) private readonly activeAccountId: number = 0;
    @State private readonly account: Account = Nextcloud.getAccountById(this.activeAccountId);
    @State private transferManager: TransferManagerImpl = TransferManager;
    private downloadQueue: DownloadQueue = new DownloadQueue();
    private pendingMoveTo: Map<string, string> = new Map();

    onAliasChanged(): void {
        CloudSyncApi.updateCustomAlias(this.path, this.alias);
    }

    async aboutToAppear(): Promise<void> {
        Logger.Info(TAG, `pcAbility aboutToAppear`);
        await PermissionManager.RequestPermission(this.getUIContext(), ["ohos.permission.FILE_ACCESS_PERSIST"])
        if (this.path) {
            CloudSyncApi.connect(this.path);
        }
        CloudSyncApi.registerFileChangeMonitor((info: CloudSyncApi.FileChangeInfo) => {
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
        });

        try {
            await fileShare.activatePermission([{
                uri: fileUri.getUriFromPath(this.path),
                operationMode: OPERATION_MODES
            }]);
            Logger.Info(TAG, `activate permission done`);
        } catch (e) {
            Logger.Error(TAG, `failed to activate: ${JSON.stringify(e)}`);
        }
        this.files = await ListFiles(this.account, '/');
    }

    aboutToDisappear(): void {
        CloudSyncApi.disconnect(this.path);
    }

    build() {
        Row({ space: 16 }) {
            Column({ space: 16 }) {
                Text(`Root Path: ${this.path}`)

                TextInput({ text: this.alias!! })

                Button('select path')
                    .onClick(async () => {
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
                        this.path = path;

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
                    })

                Button('create root dir')
                    .onClick(async () => {
                        let addResult: number = CloudSyncApi.add("Moody 的 Nextcloud", this.path);
                        Logger.Info(TAG, `Add: ${addResult}`)
                    })

                Button('connect')
                    .onClick(async () => {
                        CloudSyncApi.connect(this.path);
                    })

                Button('disconnect')
                    .onClick(() => {
                        CloudSyncApi.disconnect(this.path);
                    })

                Button('remove root dir')
                    .onClick(() => {
                        CloudSyncApi.remove(this.path);
                    })
            }
            .padding(8)
            .width(300)
            .backgroundColor($r('sys.color.glass_material_outline_secondary'))

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

                    Button('sync all')
                        .onClick(async () => {
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
                                        fileIo.mkdirSync(this.path + '/' + next.relativePath);
                                    } catch (e) {
                                    }
                                } else {
                                    await DownloadFile(this.account, next.relativePath, this.path + '/' + next.relativePath);
                                }
                                Logger.Info(TAG, next.relativePath);
                            }
                            Logger.Info(TAG, `download completed`);
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
            .width(600)
            .padding(8)
            .border({ color: Color.Blue, width: 2 })
        }
        .width('100%')
        .height('100%')
        .margin(16)
    }
}
