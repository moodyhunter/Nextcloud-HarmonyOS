import { DirectoryEntry, ListFiles, Logger } from 'nextcloud';
import { common } from '@kit.AbilityKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { Constants } from '../utils/Common';
import * as CloudSyncApi from '../utils/CloudSyncApi';

const TAG = 'PcAbility'

@Entry
@Component
struct PCAbility {
    @StorageLink(Constants.PC_CLOUD_DISK_PATH) private path: string = '';
    @StorageLink(Constants.PC_CLOUD_DISK_ALIAS) @Watch('onAliasChanged') private alias: string = 'Moody 的 Nextcloud';
    @State private opHistory: CloudSyncApi.FileChangeInfo[] = [];
    @State private files: DirectoryEntry[] = [];

    onAliasChanged(): void {
        CloudSyncApi.updateCustomAlias(this.path, this.alias);
    }

    async aboutToAppear(): Promise<void> {
        Logger.Info(TAG, `pcAbility aboutToAppear`);
        if (this.path) {
            CloudSyncApi.connect(this.path);
        }
        CloudSyncApi.registerFileChangeMonitor((info: CloudSyncApi.FileChangeInfo) => {
            Logger.Info(TAG, `${CloudSyncApi.FileChangeOperationType[info.operationType]} ::: '${info.relativePath}'`);
            this.opHistory = [info, ...this.opHistory];
        });

        this.files = await ListFiles('/');
        for (let f of this.files) {
            Logger.Info(TAG, `${JSON.stringify(f)}`);
        }
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
                            defaultFilePathUri: 'file://docs/storage/Users/currentUser/',
                            maxSelectNumber: 1,
                            selectMode: picker.DocumentSelectMode.FOLDER
                        });
                        if (items.length !== 1) {
                            Logger.Error(TAG, `???`);
                            return;
                        }
                        let path = new fileUri.FileUri(items[0]).path;
                        this.path = path;

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

                    Button('apply')
                        .onClick(async () => {
                            let state: CloudSyncApi.SyncFileState = {
                                name: 'testfile',
                                size: 12345,
                                syncState: CloudSyncApi.SyncState.SYNCING,
                            };
                            CloudSyncApi.setLocalFileState(this.path, [state]);
                        })
                }
                .padding(8)
                .width('100%')
                .backgroundColor($r('sys.color.glass_material_outline_secondary'))

                Column({ space: 8 }) {
                    Text('Operation History:')
                    List() {
                        ForEach(this.opHistory, (item: CloudSyncApi.FileChangeInfo, index) => {
                            ListItem() {
                                Row() {
                                    Text(`${index + 1}. `)
                                    Text(`FileId: ${item.relativePath}, Op: ${CloudSyncApi.FileChangeOperationType[item.operationType]}`)
                                }
                            }
                        })
                    }
                    .width('100%')
                    .height(350)
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
