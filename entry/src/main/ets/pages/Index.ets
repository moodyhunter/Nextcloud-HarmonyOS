import { Account, Logger, NCommon, Nextcloud } from 'nextcloud';
import { App, promptAction } from '@kit.ArkUI';
import { Path } from '../utils/Path';
import { UploadPage } from './UploadPage';
import { LoginPage } from './LoginPage';
import { SettingsPage } from './SettingsPage';
import { FolderPage } from './FolderPage';
import { Constants, FolderViewMode } from '../utils/Common';
import { PermissionManager } from '../utils/PermissionManager';
import { PhotoAssetsManager } from '../utils/PhotoAssetsManager';
import { PhotoMonitor } from '../utils/PhotoMonitor';
import { ShowToast } from '../utils/Utils';
import { Permissions } from '@kit.AbilityKit';

const TAG = "Page-Index";

const EXIT_TOAST_DURATION: number = 2000;

@Entry
@Component
struct Index {
    @State currentIndex: number = 0;
    @StorageLink(Constants.VIEW_MODE_KEY) viewMode: FolderViewMode = FolderViewMode.TwoColumns;
    @Provide('FolderList.PathStack') pathStack: NavPathStack = new NavPathStack();
    @StorageLink(Constants.PHONE_ACTIVE_ACCOUNT_ID) private readonly activeAccountId: number = 0;
    @State private readonly account: Account = Nextcloud.getAccountById(this.activeAccountId);
    @State private loginPageDialogId: number = 0;
    private backedOnce: boolean = false;

    onBackPress(): boolean {
        Logger.Info(TAG, `onBackPressed on tab ${this.currentIndex}`);
        if (this.currentIndex !== 0) {
            return false; // not on files tab, let system handle it
        }

        if (this.pathStack.size() > 0) {
            return true; // go back to parent level
        }

        if (this.backedOnce) {
            return false; // exit directly
        } else {
            this.backedOnce = true;
            setTimeout(() => {
                this.backedOnce = false;
            }, EXIT_TOAST_DURATION);

            ShowToast(this.getUIContext(), $r('app.string.swipe_back_again_to_exit'), EXIT_TOAST_DURATION);
            return true;
        }
    }

    async aboutToAppear() {
        Logger.Info(TAG, `aboutToAppear`);
        let context = this.getUIContext();
        const PERMISSIONS: Permissions[] = [
            'ohos.permission.READ_IMAGEVIDEO',
            'ohos.permission.MEDIA_LOCATION',
        ];
        let result = await PermissionManager.RequestPermission(context, PERMISSIONS);
        Logger.Info(TAG, `Request permission result: ${result}`);
        PhotoAssetsManager.initialize(NCommon.Preference.categories);
        PhotoMonitor.beginMonitorPhotoChange();
    }

    async doLogin() {
        let context = this.getUIContext();
        let options: promptAction.CustomDialogOptions = {
            builder: () => {
                return this.LoginPageDialog();
            },
            isModal: true,
            autoCancel: false,
        };

        try {
            this.loginPageDialogId = await context.getPromptAction().openCustomDialog(options);
            Logger.Info(TAG, `done`);
        } catch (error) {
            Logger.Error(TAG, `${JSON.stringify(error)}`);
        }
    }

    onPageShow() {
        App.setImageCacheCount(500);
        App.setImageRawDataCacheSize(1024 * 1024 * 100); // 100MB
        App.setImageFileCacheSize(1024 * 1024 * 500); // 100MB

        if (!Nextcloud.hasAccounts()) {
            this.doLogin();
        }
    }

    build() {
        Tabs({ barPosition: BarPosition.End }) {
            TabContent() {
                Flex({ direction: FlexDirection.Column }) {
                    Navigation(this.pathStack) {
                        FolderPage({ account: this.account, currentPath: new Path() })
                    }
                    .navBarWidth(0)
                    .mode(NavigationMode.Stack)

                    Row({ space: 10 }) {
                        Button(FolderViewMode[this.viewMode])
                            .onClick(() => {
                                this.viewMode = (this.viewMode % 3) + 1;
                            })
                            .width(100)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .justifyContent(FlexAlign.Center)
                    .height(60)
                    .margin({ top: 10, bottom: 10 })
                }
            }
            .tabBar($r("app.string.tab_files"))

            TabContent() {
                UploadPage()
                    .width('100%')
                    .height('100%')
            }
            .tabBar($r('app.string.tab_upload'))

            TabContent() {
                SettingsPage({ currentAccount: this.account })
                    .width('100%')
                    .height('100%')
            }
            .tabBar($r('app.string.tab_settings'))
        }
        .onChange((index: number) => {
            this.currentIndex = index;
        })
        .width('100%')
        .height('100%')
        .scrollable(false)
    }

    @Builder
    private LoginPageDialog() {
        LoginPage({ dialogId: this.loginPageDialogId })
    }
}
