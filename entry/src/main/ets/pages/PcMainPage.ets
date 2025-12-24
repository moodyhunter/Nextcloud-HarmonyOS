import { add, connect, disconnect, remove } from 'libcloudsync.so';
import { Logger } from 'nextcloud';
import { common } from '@kit.AbilityKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { Constants } from '../utils/Common';

const TAG = 'PcAbility'

@Entry
@Component
struct PCAbility {
    @StorageLink(Constants.PC_CLOUD_DISK_PATH) private path: string = '';

    aboutToAppear(): void {
        Logger.Info(TAG, `pcAbility aboutToAppear`);
    }

    aboutToDisappear(): void {
        disconnect(this.path);
    }

    build() {
        Column({ space: 10 }) {
            Text(`Root Path: ${this.path}`)

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
                    let addResult = add("Moody 的 Nextcloud", this.path);
                    Logger.Info(TAG, `Add: ${addResult}`)
                })

            Button('connect')
                .onClick(async () => {
                    connect(this.path);
                })

            Button('disconnect')
                .onClick(() => {
                    disconnect(this.path);
                })

            Button('remove root dir')
                .onClick(() => {
                    remove(this.path);
                })
        }
        .margin(16)
    }
}
