import { Logger, LoginFlow, Nextcloud } from 'nextcloud';
import { LengthMetrics } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { ShowAlertDialog, ShowToast } from '../utils/Utils';

const TAG = 'Pages/LoginPage';

@ComponentV2
export struct LoginPage {
    @Require @Param public dialogId: number;
    private webController: webview.WebviewController = new webview.WebviewController();
    private loginFlow = new LoginFlow();
    @Local private hostname: string = '';
    @Local private loginStarted: boolean = false;

    async doLogin(): Promise<void> {
        await webview.WebCookieManager.clearAllCookies();
        let initResult = await this.loginFlow.initLogin(this.hostname);
        if (initResult.kind === 'error') {
            Logger.Error(TAG, `Login failed: ${initResult.error}`);
            ShowAlertDialog(this.getUIContext(), "Login Failed", `Login failed with domain: '${this.hostname}', ${initResult.error}`);
            return;
        }

        this.startUserLoginProcess(initResult.data);

        let loginResult = await this.loginFlow.loginPollRepeatedly();
        switch (loginResult.kind) {
            case 'ok': {
                await Nextcloud.addAccount(loginResult.account);
                ShowAlertDialog(this.getUIContext(), "Login Successful", `Welcome, ${loginResult.account.username}!`);
                this.closeDialog();
                break;
            }
            case 'cancelled': {
                ShowAlertDialog(this.getUIContext(), "Login Failed", "Operation Cancelled");
                break;
            }
        }
    }

    startUserLoginProcess(loginUrl: string) {
        try {
            this.webController.loadUrl(loginUrl);
            Logger.Info(TAG, "Successfully opened login url");
            this.loginStarted = true;
        } catch (error) {
            ShowAlertDialog(this.getUIContext(), "Login Failed", `Failed to open login url: ${JSON.stringify(error)}`);
            Logger.Error(TAG, `Failed to open login url: ${JSON.stringify(error)}`);
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
                        this.loginFlow.cancelPolling();
                        this.loginStarted = false;
                        ShowToast(this.getUIContext(), "Cancelled", 2000);
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
                    TextInput({ placeholder: 'https://nextcloud.com', text: this.hostname!! })
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


@Preview
@Component
struct LoginPagePreview {
    @State private dialogId: number = 0;

    build() {
        LoginPage({ dialogId: this.dialogId })
            .width(300)
            .height(500)
    }
}
