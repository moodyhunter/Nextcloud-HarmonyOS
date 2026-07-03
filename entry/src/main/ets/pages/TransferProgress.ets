import { JobManager, TransferJob } from 'nextcloud';
import { ShowToast } from '../utils/Utils';

@ComponentV2
export struct TransferProgress {
    @Builder
    transferProgressItem(job: TransferJob) {
        Column() {
            Text(job.filename)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.Start)
                .width('100%')

            Row({ space: 16 }) {
                Progress({
                    value: job.transferredSize,
                    total: job.totalSize,
                })
                    .flexShrink(1)

                Text(job.progressPercentText)
                    .width(60)
                    .textAlign(TextAlign.End)
            }
            .width('100%')
        }
        .width('100%')
        .borderRadius(16)
        .padding(8)
        .backgroundColor($r('sys.color.gray_02'))
    }

    build() {
        Column({ space: 16 }) {
            List({ space: 8 }) {
                LazyForEach(JobManager.tasks, (item: TransferJob) => {
                    ListItem() {
                        this.transferProgressItem(item)
                    }
                }, (item: TransferJob, _index: number) => {
                    return `${item.id}`
                })
            }
            .width('100%')
            .height('100%')
            .flexShrink(1)
            .flexGrow(1)

            Button('Clear')
                .onClick(() => {
                    JobManager.tasks.clear();
                    ShowToast(this.getUIContext(), `Cleared!`, 2000);
                })
                .backgroundColor(Color.Red)
        }
        .padding(16)
        .background($r('sys.color.background_primary'))
        .width('100%')
        .height('100%')
    }
}
