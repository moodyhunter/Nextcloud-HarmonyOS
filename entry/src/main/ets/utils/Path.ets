import { Logger } from 'nextcloud';

const TAG = "Util-Path";

interface PathProps {
    path?: string;
    parts?: string[];
}

@Observed
export class Path {
    private parts: string[];

    constructor(props?: PathProps) {
        if (!props) {
            props = { path: "/" };
        }

        // cannot have both path and parts
        if (props.path && props.parts) {
            Logger.Error(TAG, "Cannot have both path and parts in Path constructor");
            throw new Error("Cannot have both path and parts in Path constructor");
        }

        if (props.path) {
            this.parts = Path.Resolve(Path.GetParts(props.path));
        } else if (props.parts) {
            this.parts = Path.Resolve(props.parts);
        } else {
            this.parts = [];
        }
    }

    get leaf() {
        return this.parts[this.parts.length - 1];
    }

    get parentName() {
        if (this.parts.length < 2) {
            return "";
        }
        return this.parts[this.parts.length - 2];
    }

    private static GetParts(path: string): string[] {
        return path.split("/").filter(p => p !== "");
    }

    private static Resolve(parts: string[]) {
        // iterate over parts and resolve ".." and "."
        let resolvedParts: string[] = [];
        for (let p of parts) {
            if (p === "..") {
                resolvedParts.pop();
            } else if (p !== ".") {
                resolvedParts.push(p);
            }
        }

        return resolvedParts;
    }

    public getParents() {
        let parts = [''];
        for (let i = 0; i < this.parts.length - 1; i++) {
            parts.push(this.parts[i]);
        }
        return parts;
    }

    path(isDir: boolean = true) {
        let result = "/" + this.parts.join("/");
        // make sure the path ends with a slash
        if (result.length > 1 && !result.endsWith("/") && isDir) {
            result += "/";
        }

        return result;
    }

    getChild(path: string) {
        let child = new Path({ parts: this.parts });
        child.goTo(path);
        return child;
    }

    isRootPath() {
        return this.parts.length === 0;
    }

    goUp() {
        if (this.isRootPath()) {
            return;
        }
        this.parts = this.parts.slice(0, -1);
    }

    goTo(relativePath: string) {
        let parts = Path.GetParts(relativePath);
        this.parts = Path.Resolve(this.parts.concat(parts));
    }
}
