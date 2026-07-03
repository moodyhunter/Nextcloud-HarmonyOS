import { DAV_PROPERTY_TYPES, DavPropsType, DavResponse, DavResponseRoot } from './DavTypes';
import { Logger } from '../Utils/Logger';

const TAG = 'webdav/DirEntryParserStateMachine';

export interface DirectoryEntry {
  name: string;
  isDirectory: boolean;
  mime: string;
  size: string;
  fileId: string;
  has_preview: boolean;
}

enum ParserStatus {
  MultiStatus,

  IN_Response,
  ShouldAddHref,
  ShouldAddProperty,
  ShouldAddStatus,

  Final,
};

export class DirEntryParserStateMachine {
  private state: ParserStatus = ParserStatus.MultiStatus;

  private response_root: DavResponseRoot;
  private current_response: DavResponse;
  private current_text: string;
  private tag_stack: DavPropsType[];

  constructor() {
    this.tag_stack = [];
    this.current_text = "";
    this.response_root = {
      "d:multistatus": {
        "d:response": [],
      },
    };
    this.current_response = {
      "d:href": "",
      "d:propstat": {
        "d:prop": {},
        "d:status": "",
      },
    };
  }

  resetResponse() {
    this.current_response = {
      "d:href": "",
      "d:propstat": {
        "d:prop": {},
        "d:status": "",
      },
    };
  }

  onStartChildTag(name: string) {
    this.tag_stack.push(name);

    switch (this.state) {
      case ParserStatus.MultiStatus: {
        if (name === "d:response") {
          this.state = ParserStatus.IN_Response;
          this.resetResponse();
        }
        break;
      }
      case ParserStatus.IN_Response: {
        if (name === "d:href") {
          this.state = ParserStatus.ShouldAddHref;
          this.current_text = "";
        } else if (name === "d:prop") {
          this.state = ParserStatus.ShouldAddProperty;
          this.current_text = "";
        } else if (name === "d:status") {
          this.state = ParserStatus.ShouldAddStatus;
          this.current_text = "";
        } else if (name === "d:propstat") {
          // do nothing
        } else {
          Logger.Warn(TAG, `Unknown property in state 'Response': ${name}`);
        }
        break;
      }
      case ParserStatus.ShouldAddHref:
      case ParserStatus.ShouldAddProperty:
        break;
    }
  }

  onEndTag() {
    let tagName = this.tag_stack.pop();

    switch (this.state) {
      case ParserStatus.MultiStatus: {
        if (tagName !== "d:multistatus") {
          Logger.Error(TAG, `Unexpected end tag: ${tagName}`);
          break;
        }

        this.state = ParserStatus.Final;
        break;
      }
      case ParserStatus.IN_Response: {
        if (tagName === "d:propstat") {
          // do nothing
          break;
        }

        if (tagName !== "d:response") {
          Logger.Error(TAG, `Unexpected end tag in Response: ${tagName}`);
          break;
        }

        this.response_root["d:multistatus"]["d:response"].push(this.current_response);
        this.state = ParserStatus.MultiStatus;
        this.resetResponse();
        break;
      }
      case ParserStatus.ShouldAddHref: {
        this.current_response["d:href"] = this.current_text;
        this.state = ParserStatus.IN_Response;
        this.current_text = "";
        break;
      }
      case ParserStatus.ShouldAddProperty: {
        if (tagName === "d:prop") {
          this.state = ParserStatus.IN_Response;
          break;
        }

        if (DAV_PROPERTY_TYPES.includes(tagName)) {
          this.current_response["d:propstat"]["d:prop"][tagName] = this.current_text;
          this.current_text = "";
        } else if (tagName === "d:resourcetype") {
          // skip
        } else if (tagName === "d:collection") {
          this.current_response["d:propstat"]["d:prop"]["d:resourcetype"] = "d:collection";
        } else {
          Logger.Warn(TAG, `Unknown property: ${tagName}`);
        }
        break;
      }
      case ParserStatus.ShouldAddStatus: {
        this.current_response["d:propstat"]["d:status"] = this.current_text;
        this.state = ParserStatus.IN_Response;
        break;
      }
    }
  }

  onText(text: string) {
    this.current_text += text;
  }

  getDirEntryList(prefix: string): DirectoryEntry[] {
    let entries: DirectoryEntry[] = [];

    for (let response of this.response_root["d:multistatus"]["d:response"]) {
      let href = response["d:href"];
      let isDirectory = response["d:propstat"]["d:prop"]["d:resourcetype"]?.includes("d:collection") ?? false;
      let mime = response["d:propstat"]["d:prop"]["d:getcontenttype"] ?? "";
      let size = response["d:propstat"]["d:prop"]["d:getcontentlength"] ?? "";
      let fileId = response["d:propstat"]["d:prop"]["oc:fileid"] ?? "";
      let has_preview = response["d:propstat"]["d:prop"]["nc:has-preview"] === "true";

      href = decodeURIComponent(href);

      // remove prefix
      if (href.startsWith(prefix)) {
        href = href.substring(prefix.length);
      }

      if (href.length === 0) {
        // skip root directory
        continue;
      }

      entries.push({
        name: href,
        isDirectory,
        mime,
        size,
        fileId,
        has_preview,
      });
    }

    return entries;
  }
}
