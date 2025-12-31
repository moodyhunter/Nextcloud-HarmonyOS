import { DirectoryEntry, FilesDataSource, Logger, NCommon } from 'nextcloud';
import { Path } from '../utils/Path';
import { PREVIEW_PAGE_NAME, PreviewPageProps } from './PreviewPage';
import { LengthMetrics, promptAction } from '@kit.ArkUI';
import { FormatBytes } from '../utils/Utils';
import { Constants, FolderViewMode } from '../utils/Common';

const TAG = "Page-FolderPage";

export let FOLDER_PAGE_NAME: string = "FolderPage";

@Component
export struct FolderPage {
    @StorageLink(Constants.VIEW_MODE_KEY) viewMode: FolderViewMode = FolderViewMode.TwoColumns;
    @Consume('FolderList.PathStack') pageInfos: NavPathStack;
    @Prop currentPath: Path;

    static formatSubtitle(mime: string, size: string) {
        let mimeParts = mime.split('/');
        return [mimeParts[1] ?? mimeParts[0] ?? mime, size].join('·');
    }

    async onItemClicked(entry: DirectoryEntry) {
        let pathInfo: NavPathInfo;
        Logger.Info(TAG, JSON.stringify(entry));
        if (entry.isDirectory) {
            pathInfo = new NavPathInfo(FOLDER_PAGE_NAME, this.currentPath.getChild(entry.name));
        } else if (entry.has_preview) {
            let props: PreviewPageProps = { entry: entry, fullPath: this.currentPath.getChild(entry.name) };
            pathInfo = new NavPathInfo(PREVIEW_PAGE_NAME, props);
        } else {
            try {
                this.getUIContext().getPromptAction().showToast({
                    message: `No preview available for ${entry.name}`,
                    duration: 2000,
                });
            } catch (error) {
                Logger.Error(TAG, `Failed to show toast: ${JSON.stringify(error)}`);
            }

            return;
        }

        this.pageInfos.pushPath(pathInfo);
    }

    @Builder
    navTitleBar() {
        Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
            Column() {
                Text(this.currentPath.isRootPath() ? $r('app.string.app_name') : this.currentPath.leaf)
                    .fontSize($r('sys.float.titlebar_main_title_text_font_size'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontWeight(FontWeight.Bold)

                if (!this.currentPath.isRootPath()) {
                    Text() {
                        ForEach(this.currentPath.getParents(), (part: string, index) => {
                            Span(part + '/')
                                .onClick(() => {
                                    Logger.Info(TAG, `Go to path part: ${part}`);
                                    this.pageInfos.popToIndex(index);
                                })
                        })
                    }
                    .fontSize($r('sys.float.titlebar_subheader_size'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .ellipsisMode(EllipsisMode.START)
                }
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .height('100%')
            .margin(8)

            if (!this.currentPath.isRootPath()) {
                Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
                    SymbolGlyph($r('sys.symbol.house'))
                        .fontColor([$r('sys.color.titlebar_icon_color')])
                        .fontSize(24)
                }
                .width(40)
                .height(40)
                .onClick(() => {
                    Logger.Info(TAG, `Go to root path`);
                    this.pageInfos.clear();
                })
            }
        }
        .margin({ left: 8, right: 16 })
    }

    build() {
        NavDestination() {
            List({ space: 5 }) {
                LazyForEach(new FilesDataSource(this.currentPath.path()), (d: DirectoryEntry) => {
                    ListItem() {
                        Button({ type: ButtonType.Normal }) {
                            Row() {
                                if (d.has_preview) {
                                    Image(NCommon.MakePreviewUrl(d.fileId))
                                        .width(32)
                                        .height(32)
                                        .margin({ right: 10 })
                                } else {
                                    Text(d.isDirectory ? '📁' :
                                        (d.mime.startsWith("image") ? "🖼️" :
                                            (d.mime.startsWith("video") ? '🎥' : '📄')))
                                        .fontSize(32)
                                        .margin({ right: 10 })
                                }

                                Column() {
                                    Text(d.name.replace(/\/$/, ''))
                                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                                        .maxLines(1)
                                        .margin({ bottom: 2 })

                                    Text(d.isDirectory ? 'directory' :
                                        (FolderPage.formatSubtitle(d.mime, FormatBytes(d.size))))
                                        .fontSize(10)
                                        .maxLines(1)
                                        .fontStyle(FontStyle.Italic)
                                }
                                .alignItems(HorizontalAlign.Start)
                                .width(this.viewMode == 1 ? '75%' : '70%')
                            }
                        }
                        .backgroundColor('#00000000')
                        .borderRadius(0)
                        .onClick(async () => {
                            await this.onItemClicked(d);
                        })
                        .width('100%')
                        .height(64)
                        .padding({ left: 10, right: 10 })
                    }
                })
            }
            .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(80) })
            .lanes(this.viewMode)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .width('auto')
            .height('auto')
            .flexGrow(1)
            .cachedCount(10)
        }
        .title(this.navTitleBar)
    }
}

@Builder
export function FolderPageBuilder(_name: string, currentPath: Path) {
    FolderPage({ currentPath });
}
