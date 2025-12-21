import { LoginProcess, NCommon } from 'nextcloud';
import { LengthMetrics } from '@kit.ArkUI';
import { Logger } from 'nextcloud/src/main/ets/Logger';
import { webview } from '@kit.ArkWeb';

const TAG = 'pages/LoginPage'

@Preview
@Component
export struct LoginPage {
    @Link public dialogId: number;
    private webController: webview.WebviewController = new webview.WebviewController();
    private loginProcess = new LoginProcess();
    @State private loginStarted: boolean = false;

    async doLogin() {
        if (!this.loginProcess.hasAppPassword()) {
            Logger.Debug(TAG, "No app password, start login process");
            try {
                await webview.WebCookieManager.clearAllCookies();
                let initResult = await this.loginProcess.initLogin();
                if (!initResult.success) {
                    Logger.Error(TAG, `Login failed: ${initResult.errorMsg}`);
                    this.getUIContext().showAlertDialog({
                        title: "Login Failed",
                        message: `Login failed with domain: '${NCommon.Preference.hostname}', ${initResult.errorMsg}`,
                    });
                    return;
                }

                this.loginStarted = true;
                this.webController.loadUrl(initResult.loginUrl);
                Logger.Info(TAG, "Successfully opened login url");

                let result = await this.loginProcess.loginPollRepeatedly();
                Logger.Info(TAG, "Login result: " + JSON.stringify(result));

                if (result.cancelled) {
                    this.getUIContext().showAlertDialog({
                        title: "Login Failed",
                        message: "Operation Cancelled",
                    });
                } else {
                    this.getUIContext().showAlertDialog({
                        title: "Welcome to use NextCloud",
                        message: "Welcome, " + result.loginName,
                    });
                    this.closeDialog();
                }
            } catch (e) {
                this.getUIContext().showAlertDialog({
                    title: "Login failed",
                    message: JSON.stringify(e),
                })
            }
        } else {
            Logger.Info(TAG, "Already have app password, skip login process");
            this.getUIContext().showAlertDialog({
                title: "Welcome",
                message: NCommon.Preference.username,
            });
        }
    }

    build() {
        Flex({ direction: FlexDirection.Column }) {
            RelativeContainer() {
                if (this.loginStarted) {
                    Button() {
                        Row({ space: 4 }) {
                            SymbolGlyph($r('sys.symbol.trash'))
                                .width(16)
                                .height(16)
                                .fontColor([Color.White])
                            Text('Cancel')
                        }
                        .margin(8)
                    }
                    .foregroundColor(Color.White)
                    .backgroundColor(Color.Red)
                    .height(32)
                    .onClick(() => {
                        this.loginProcess.cancelPolling();
                        this.loginStarted = false;
                        NCommon.Preference.password = "";
                        this.getUIContext().getPromptAction().showToast({
                            message: "Logged out",
                            duration: 2000,
                        });
                    })
                    .alignRules({
                        left: { anchor: '__container__', align: HorizontalAlign.Start },
                        center: { anchor: '__container__', align: VerticalAlign.Center }
                    })
                }

                Text($r('app.string.login'))
                    .fontSize($r('sys.float.titlebar_main_title_text_font_size'))
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                    .alignRules({
                        middle: { anchor: '__container__', align: HorizontalAlign.Center },
                        center: { anchor: '__container__', align: VerticalAlign.Center }
                    })

                Button({ type: ButtonType.Circle, stateEffect: true }) {
                    SymbolGlyph($r('sys.symbol.xmark'))
                        .width(16)
                        .height(16)
                }
                .width(32)
                .height(32)
                .onClick(() => {
                    this.closeDialog();
                })
                .buttonStyle(ButtonStyleMode.NORMAL)
                .alignRules({
                    right: { anchor: '__container__', align: HorizontalAlign.End },
                    center: { anchor: '__container__', align: VerticalAlign.Center }
                })
            }
            .height(44)
            .margin(16)

            if (!this.loginStarted) {
                Text('Type the URL of your Nextcloud instance:')
                    .margin({ left: 24, right: 24, bottom: 8 })
                Flex({ alignItems: ItemAlign.Center, direction: FlexDirection.Row, space: { main: LengthMetrics.vp(8) } }) {
                    TextInput({ placeholder: 'https://nextcloud.com', text: NCommon.Preference.hostname })
                        .onChange((value: string) => {
                            NCommon.Preference.hostname = value;
                        })
                        .flexGrow(1)

                    Button({ type: ButtonType.Circle }) {
                        SymbolGlyph($r('sys.symbol.paperplane_right_fill'))
                            .width(16)
                            .height(16)
                            .fontColor([Color.White])
                    }
                    .width(40)
                    .height(40)
                    .onClick(() => {
                        this.doLogin();
                    })
                }
                .margin({ left: 16, right: 16 })
                .constraintSize({ minHeight: 48 })
            }

            Web({ src: "about:blank", controller: this.webController })
                .id("webview")
                .width('100%')
                .height('100%')
                .flexGrow(1)
                .visibility(this.loginStarted ? Visibility.Visible : Visibility.Hidden)
        }
    }

    private closeDialog() {
        Logger.Info(TAG, `dialogId: ${this.dialogId}`);
        this.getUIContext().getPromptAction().closeCustomDialog(this.dialogId);
    }
}
