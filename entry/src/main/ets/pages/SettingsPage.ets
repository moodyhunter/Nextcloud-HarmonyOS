import {
    Account, Logger, NCommon, Nextcloud, LocalFolder, LocalFolderType, Category,
    PhotoAssetsManager
} from 'nextcloud';
import { LengthMetrics } from '@kit.ArkUI';
import application from '@ohos.app.ability.application';
import { ShowToast } from '../utils/Utils';

const TAG = 'pages/Settings';

@Component
export struct SettingsPage {
    scroller: Scroller = new Scroller();
    @ObjectLink public currentAccount: Account;
    @State private username: string = "<username>";
    @State private hostname: string = "<hostname>";
    @State private uploadReplaceExisting: boolean = false;
    @State private uploadBaseDirectory: string = '/';

    private categories: Category[] = [];
    aboutToAppear(): void {
        this.categories = Array.from(PhotoAssetsManager.categories.values());
        this.categories.sort((a: Category, b: Category): number => {
            if (a.instantUploadEnabled !== b.instantUploadEnabled) {
                return a.instantUploadEnabled ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        })
        this.doLoadSettings();
    }

    build() {
        Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Center, space: { main: LengthMetrics.vp(8) } }) {
            Text($r('app.string.tab_settings'))
                .fontSize($r('sys.float.titlebar_main_title_text_font_size'))
                .fontWeight(FontWeight.Bold)
                .fontSize(24)
                .padding({ left: 16, top: 16, bottom: 24 })
                .width('100%')

            Scroll(this.scroller) {
                Flex({ direction: FlexDirection.Column }) {
                    Column() {
                        Text($r('app.string.login_info'))
                            .width('100%')
                            .fontSize($r('sys.float.subheader_title_font_size'))
                            .fontWeight(FontWeight.Bold)
                            .margin({ bottom: 4 })

                        Row() {
                            Text($r('app.string.username'))
                            Text(this.username)
                                .copyOption(CopyOptions.LocalDevice)
                        }
                        .justifyContent(FlexAlign.SpaceBetween)
                        .width('100%')
                        .height(24)

                        Row() {
                            Text($r('app.string.hostname'))
                            Text(this.hostname)
                                .copyOption(CopyOptions.LocalDevice)
                        }
                        .justifyContent(FlexAlign.SpaceBetween)
                        .width('100%')
                        .height(24)
                    }
                    .backgroundColor($r('sys.color.gray_02'))
                    .borderRadius(8)
                    .padding(12)

                    Divider()
                        .margin({ top: 16, bottom: 16 })

                    Column() {
                        Text($r('app.string.upload'))
                            .width('100%')
                            .fontWeight(FontWeight.Bold)
                            .fontSize($r('sys.float.subheader_title_font_size'))
                            .margin({ bottom: 4 })

                        Row() {
                            Text($r('app.string.upload_base_directory'))
                            Text(this.uploadBaseDirectory)
                                .copyOption(CopyOptions.LocalDevice)
                        }
                        .justifyContent(FlexAlign.SpaceBetween)
                        .width('100%')
                        .height(24)

                        Row() {
                            Text($r('app.string.replace_existing_files'))
                            Row({ space: 8 }) {
                                Text(this.uploadReplaceExisting ? $r('app.string.yes') : $r('app.string.no'))
                                Toggle({ type: ToggleType.Switch, isOn: this.uploadReplaceExisting })
                                    .onChange((value: boolean) => {
                                        this.uploadReplaceExisting = value;
                                    })
                                    .height('60px')
                                    .width('107px')
                            }
                            .alignItems(VerticalAlign.Center)
                        }
                        .justifyContent(FlexAlign.SpaceBetween)
                        .width('100%')
                        .height(24)
                    }
                    .backgroundColor($r('sys.color.gray_02'))
                    .borderRadius(8)
                    .padding(12)

                    Divider()
                        .margin({ top: 16, bottom: 16 })

                    Column({ space: 8 }) {
                        Text($r('app.string.categories'))
                            .width('100%')
                            .fontWeight(FontWeight.Bold)
                            .fontSize($r('sys.float.subheader_title_font_size'))
                            .margin({ bottom: 4 })

                        Repeat(this.categories)
                            .each((item: RepeatItem<Category>) => {
                                Row() {
                                    Column() {
                                        Text(item.item.name)
                                        Text(`Album Id: ${item.item.localFolder.albumId}`)
                                            .fontSize(10)
                                    }
                                    .alignItems(HorizontalAlign.Start)

                                    Row({ space: 8 }) {
                                        Text('Upload')
                                        Toggle({ type: ToggleType.Switch, isOn: item.item.instantUploadEnabled })
                                            .onChange((value: boolean) => {
                                                item.item.instantUploadEnabled = value;
                                                Nextcloud.getSyncFolderManager()
                                                    .updateLocalFolder(item.item.localFolder);
                                            })
                                            .height('60px')
                                            .width('107px')
                                    }
                                    .alignItems(VerticalAlign.Center)
                                }
                                .justifyContent(FlexAlign.SpaceBetween)
                                .width('100%')
                                .backgroundColor($r('sys.color.gray_03'))
                                .borderRadius(8)
                                .padding(12)
                            })
                    }
                    .padding(12)
                    .backgroundColor($r('sys.color.gray_02'))
                    .borderRadius(8)
                }
                .margin({ left: 16, right: 16 })
            }
            .align(Alignment.TopStart)
            .edgeEffect(EdgeEffect.Spring)
            .flexGrow(1)

            Button($r('app.string.save_settings'), { stateEffect: true })
                .onClick(() => {
                    this.doSaveSettings();
                    ShowToast(this.getUIContext(), 'settings saved');
                })
                .margin({ top: 16, bottom: 16 })

            Button('DROP DATABASE')
                .visibility(Visibility.None)
                .backgroundColor(Color.Red)
                .onClick(async () => {
                    await Nextcloud.recreateDatabase();
                    try {
                        await application.getApplicationContext()
                            .killAllProcesses();
                    } catch (error) {
                        Logger.Error(TAG, `failed to kill all processes: ${JSON.stringify(error)}`);
                    }
                })
        }
        .background($r('sys.color.background_primary'))
        .height('100%')
        .padding({ bottom: 16 })
    }

    private doLoadSettings() {
        if (NCommon.Preference) {
            this.username = this.currentAccount.username;
            this.hostname = this.currentAccount.hostname;
            this.uploadReplaceExisting = NCommon.Preference.replaceExistingFiles;
            this.uploadBaseDirectory = NCommon.Preference.baseUploadDirectory;
        } else {
            Logger.Error(TAG, `failed to load settings, preference is undefined`);
        }
    }

    private doSaveSettings() {
        if (NCommon.Preference) {
            NCommon.Preference.replaceExistingFiles = this.uploadReplaceExisting;
            NCommon.Preference.baseUploadDirectory = this.uploadBaseDirectory;
        } else {
            Logger.Error(TAG, `failed to save settings, preference is undefined`);
        }
    }
}
