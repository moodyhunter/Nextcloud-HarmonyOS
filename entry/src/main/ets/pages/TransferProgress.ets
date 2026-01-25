import { JobManager, TransferJob } from 'nextcloud';

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
        .backgroundColor($r('sys.color.gray_03'))
    }

    build() {
        List({ space: 8 }) {
            LazyForEach(JobManager.tasks, (item: TransferJob) => {
                ListItem() {
                    this.transferProgressItem(item)
                }
            }, (item: TransferJob, _index: number) => {
                return `${item.id}`
            })
        }
        .padding(16)
        .width('100%')
        .height('100%')
        .background($r('sys.color.background_primary'))
    }
}
