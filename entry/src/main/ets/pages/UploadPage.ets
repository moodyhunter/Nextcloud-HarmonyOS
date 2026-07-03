import {
    Account,
    Category,
    Logger,
    Nextcloud,
    PhotoAssetsManager,
    RemoteFolder,
    PhotoItem,
    UploadStatus,
} from 'nextcloud';

const TAG = "Page-UploadPage"
const PHOTO_PREVIEW_SIZE = 75;

async function getUploadRemoteFolder(account: Account): Promise<RemoteFolder> {
    let remoteFolderId = account.dbAccount.config.instantUploadFolderId;
    let remoteFolder = await Nextcloud.getSyncFolderManager().getRemoteFolderById(remoteFolderId);
    if (remoteFolder === null) {
        Logger.Info(TAG, `creating instant upload remote folder`)
        // not configured, create new
        remoteFolder = await Nextcloud.getSyncFolderManager().addRemoteFolder(account, '/InstantUpload/', 'Instant Upload');
        remoteFolderId = remoteFolder.id;
        account.dbAccount.config.instantUploadFolderId = remoteFolder.id;
        await Nextcloud.updateAccount(account);
        Logger.Info(TAG, `created instant upload remote folder`)
    }
    Logger.Info(TAG, `instant upload remote dir: ${remoteFolderId}`);
    return remoteFolder!;
}

@ComponentV2
struct PhotoView {
    @Require @Param account: Account;
    @Require @Param asset: PhotoItem;
    @Require @Param category: Category;
    @Local private thumbnail: PixelMap | null = null;

    getUploadColor(status: UploadStatus): Color {
        switch (status) {
            case UploadStatus.Completed:
                return Color.Green;
            case UploadStatus.Pending:
                return Color.Pink;
            case UploadStatus.Uploading:
                return Color.Yellow;
            case UploadStatus.Failed:
            case UploadStatus.FailedCreatingPath:
                return Color.Red;
            case UploadStatus.None:
                return Color.Gray;
            case UploadStatus.Existed:
                return Color.Blue;
            default:
                return Color.Gray;
        }
    }

    build() {
        Stack() {
            Image(this.thumbnail)
                .height(PHOTO_PREVIEW_SIZE)
                .width(PHOTO_PREVIEW_SIZE)
                .objectFit(ImageFit.Cover)

            Text(this.asset.isVideo ? '▶' : '')
                .fontSize(24)
                .fontFamily('monospace')
                .fontColor(Color.Red)
        }
        .draggable(false)
        .height(PHOTO_PREVIEW_SIZE)
        .width(PHOTO_PREVIEW_SIZE)
        .borderWidth(3)
        .borderColor(this.getUploadColor(this.asset.uploadStatus))
        .onClick(async () => {
            const remoteFolder = await getUploadRemoteFolder(this.account);
            this.asset.getUploadJob(this.category.name, remoteFolder).start();
        })
        .onAppear(async () => {
            if (this.thumbnail === null) {
                this.thumbnail = await this.asset.getThumbnail({ height: 200, width: 200 });
            }
        })
    }
}

@ComponentV2
struct CategoryView {
    @Require @Param account: Account;
    @Require @Param category: Category;
    @Local private isEditing: boolean = false;
    @Local private isExpanded: boolean = false;
    @Local private viewHeight: number = 56;

    aboutToAppear(): void {
    }

    @Builder
    topBar() {
        Row({ space: 16 }) {
            Row({ space: 8 }) {
                if (this.isEditing) {
                    TextInput({ text: this.category.name })
                        .fontWeight(FontWeight.Bold)
                        .flexShrink(1)
                        .fontSize(16)
                        .borderRadius(0)
                        .onSubmit(async (enterKey: EnterKeyType, event: SubmitEvent) => {
                            if (event.text.length === 0) {
                                this.getUIContext()
                                    .getPromptAction()
                                    .showDialog({
                                        title: `Category Rename`,
                                        message: `Category name cannot be empty!`,
                                    })
                                    .catch((e: Error) => {
                                        Logger.Error(TAG, `failed to show prompt dialog, ${JSON.stringify(e)}`);
                                    });

                                event.keepEditableState();
                                return;
                            }
                            Logger.Info(TAG, `category edit onSubmit: ${EnterKeyType[enterKey]}`)
                            this.category.setAlias(event.text);
                            Nextcloud.getSyncFolderManager().updateLocalFolder(this.category.localFolder);
                        })
                        .onBlur(() => {
                            this.isEditing = false;
                        })
                } else {
                    Text(this.category.name)
                        .fontSize(24)

                    SymbolGlyph($r('sys.symbol.doc_plaintext_and_pencil'))
                        .fontSize(12)
                        .fontColor([Color.Gray])
                        .onClick(() => {
                            this.isEditing = true;
                        })
                }
            }
            .flexShrink(1)
            .height(36)

            Row({ space: 16 }) {
                Button() {
                    SymbolGlyph(this.isExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
                        .fontSize(24)
                        .fontColor([$r('sys.color.font')])
                }
                .onClick(() => {
                    this.isExpanded = !this.isExpanded;
                    this.viewHeight = this.isExpanded ? 382 : 56;
                })
                .padding(8)
                .type(ButtonType.Circle)
                .buttonStyle(ButtonStyleMode.TEXTUAL)
                .backgroundColor($r('sys.color.gray_03'))
            }
        }
        .onClick(() => {
            this.isExpanded = !this.isExpanded;
            this.viewHeight = this.isExpanded ? 382 : 56;
        })
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
    }

    @Builder
    photoGrid() {
        Grid() {
            LazyForEach(this.category.visibleItems, (asset: PhotoItem, index: number) => {
                GridItem() {
                    PhotoView({ asset: asset, category: this.category, account: this.account })
                        .enabled(this.category.instantUploadEnabled)
                }
                .width('100%')
                .onAppear(() => {
                    if (index == this.category.visibleItems.totalCount() - 1) {
                        this.category.loadNextBatch();
                    }
                })
            })
        }
        .layoutDirection(GridDirection.Row)
        .fadingEdge(true)
        .columnsTemplate(`repeat(auto-fit, ${PHOTO_PREVIEW_SIZE})`)
        .scrollBar(BarState.On)
        .edgeEffect(EdgeEffect.Spring)
        .columnsGap(8)
        .rowsGap(8)
        .cachedCount(10)
        .width('100%')
        .height('100%')
        .margin({ bottom: 12 })
    }

    build() {
        Column({ space: 8 }) {
            // Top Bar Row
            this.topBar()

            Blank()
                .height(6)

            Stack() {
                this.photoGrid();

                Column() {
                    Button($r('app.string.upload_all'))
                        .onClick(async () => {
                            const remoteFolder = await getUploadRemoteFolder(this.account);
                            this.category.uploadAllAssets(remoteFolder);
                        })
                        .backgroundColor(this.category.instantUploadEnabled ? '#0082C9' : 'gray')
                        .width('30%')
                }
                .enabled(this.category.instantUploadEnabled)
                .width('100%')
                .position({ bottom: 10 })
            }
            .width('100%')
            .height('100%')
            .constraintSize({ maxHeight: 300, minHeight: 100 })
        }
        .borderRadius(16)
        .padding({
            left: 12,
            right: 12,
            top: 8,
            bottom: 8
        })
        .backgroundColor($r('sys.color.gray_02'))
        .width('100%')
        .height(this.viewHeight)
        .renderFit(RenderFit.CENTER)
        .clip(true)
        .animation({
            duration: 250,
            curve: Curve.Friction,
            playMode: PlayMode.Normal,
        })
    }
}

@Preview
@ComponentV2
export struct UploadPage {
    @Require @Param account: Account;
    @Local private categories: Category[] = [];

    aboutToAppear(): void {
        Logger.Info(TAG, `aboutToAppear, found ${PhotoAssetsManager.categories.size} categories`);
        this.categories = Array.from(PhotoAssetsManager.categories.values());
        this.categories.sort((a: Category, b: Category): number => {
            if (a.instantUploadEnabled !== b.instantUploadEnabled) {
                return a.instantUploadEnabled ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        })
    }

    build() {
        Column() {
            List({ space: 10 }) {
                Repeat(this.categories)
                    .each((item: RepeatItem<Category>) => {
                        if (item.item.instantUploadEnabled) {
                            CategoryView({ category: item.item, account: this.account })
                        }
                    })
            }
            .width('100%')
            .height('auto')
            .padding(16)
            .flexShrink(1)
        }
        .width('100%')
        .height('100%')
        .background($r('sys.color.background_primary'))
    }
}
