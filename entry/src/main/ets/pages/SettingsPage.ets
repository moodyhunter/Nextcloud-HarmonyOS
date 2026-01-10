import { Logger, NCommon, Account } from 'nextcloud';
import { LengthMetrics } from '@kit.ArkUI';

const TAG = 'pages/Settings';

@Observed
class EditableCategory implements NCommon.CategoryConfig {
    name: string;
    patterns: string[];
    location: string;

    constructor(other: NCommon.CategoryConfig) {
        this.name = other.name;
        this.patterns = other.patterns;
        this.location = other.location;
    }
}

@Component
export struct SettingsPage {
    scroller: Scroller = new Scroller();
    @ObjectLink public currentAccount: Account;
    @State private username: string = "<username>";
    @State private hostname: string = "<hostname>";
    @State private uploadReplaceExisting: boolean = false;
    @State private uploadBaseDirectory: string = '/';
    @State private uploadCategories: EditableCategory[] = [];

    aboutToAppear(): void {
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
                    Column({ space: 4 }) {
                        Text($r('app.string.login_info'))
                            .width('100%')
                            .fontSize($r('sys.float.subheader_title_font_size'))
                            .fontWeight(FontWeight.Bold)

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

                    Divider()
                        .margin({ top: 16, bottom: 16 })

                    Column({ space: 4 }) {
                        Text($r('app.string.upload'))
                            .width('100%')
                            .fontWeight(FontWeight.Bold)
                            .fontSize($r('sys.float.subheader_title_font_size'))

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

                    Divider()
                        .margin({ top: 16, bottom: 16 })

                    Column({ space: 4 }) {
                        Text($r('app.string.categories'))
                            .width('100%')
                            .fontWeight(FontWeight.Bold)
                            .fontSize($r('sys.float.subheader_title_font_size'))

                        ForEach(this.uploadCategories, (category: EditableCategory, index: number) => {
                            Column({ space: 4 }) {
                                Row() {
                                    Text(category.name)
                                        .fontWeight(FontWeight.Bold)

                                    Text(this.uploadBaseDirectory + category.location)
                                        .fontSize(12)
                                        .fontColor(Color.Gray)
                                }
                                .justifyContent(FlexAlign.SpaceBetween)
                                .width('100%')

                                ForEach(category.patterns, (pattern: string, patternIndex: number) => {
                                    TextInput({ text: pattern })
                                        .fontSize(12)
                                        .fontFamily('monospace')
                                        .width('100%')
                                        .onChange((content) => {
                                            category.patterns[patternIndex] = content;
                                        })
                                })
                            }
                            .width('100%')
                            .padding(8)
                        })
                    }
                }
                .margin({ left: 24, right: 24 })
            }
            .align(Alignment.TopStart)
            .edgeEffect(EdgeEffect.Spring)
            .flexGrow(1)

            Button($r('app.string.save_settings'), { stateEffect: true })
                .onClick(() => {
                    this.doSaveSettings();
                    this.getUIContext().getPromptAction().showToast({
                        message: 'settings saved'
                    });
                })
                .margin({ top: 16, bottom: 16 })
        }
        .height('100%')
    }

    private doLoadSettings() {
        if (NCommon.Preference) {
            this.username = this.currentAccount.username;
            this.hostname = this.currentAccount.hostname;
            this.uploadReplaceExisting = NCommon.Preference.replaceExistingFiles;
            this.uploadBaseDirectory = NCommon.Preference.baseUploadDirectory;
            this.uploadCategories = [];
            for (let c of NCommon.Preference.categories) {
                this.uploadCategories.push(new EditableCategory(c));
            }
        } else {
            Logger.Error(TAG, `failed to load settings, preference is undefined`);
        }
    }

    private doSaveSettings() {
        if (NCommon.Preference) {
            NCommon.Preference.replaceExistingFiles = this.uploadReplaceExisting;
            NCommon.Preference.baseUploadDirectory = this.uploadBaseDirectory;
            NCommon.Preference.categories = this.uploadCategories;
        } else {
            Logger.Error(TAG, `failed to save settings, preference is undefined`);
        }
    }
}
