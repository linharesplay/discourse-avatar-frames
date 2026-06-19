import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import avatar from "discourse/helpers/avatar";
import I18n, { i18n } from "discourse-i18n";

const eq = (a, b) => a === b;
const notEq = (a, b) => a !== b;

export default class AvatarFramePreferences extends Component {
  @service currentUser;
  @service siteSettings;
  @tracked selectedFrame = this.currentUser?.custom_fields?.avatar_frame || "none";

  get frames() {
    const configStr = this.siteSettings.avatar_frames_config || "";
    const frameConfigs = configStr.split("|").filter(Boolean);
    
    const framesList = [{ id: "none", name: I18n.t("avatar_frames.none"), isLocked: false, lockedHint: null }];
    
    for (const conf of frameConfigs) {
      const parts = conf.split(":");
      if (parts.length >= 3) {
        const id = parts[0].trim();
        const name = parts[1].trim();
        const condition = parts.slice(2).join(":").trim();
        
        let isLocked = false;
        let lockedHint = null;
        
        if (condition.startsWith("tl")) {
          const requiredLevel = parseInt(condition.replace("tl", ""), 10);
          if (this.currentUser.trust_level < requiredLevel) {
            isLocked = true;
            lockedHint = I18n.t("avatar_frames.requires_level", { level: requiredLevel });
          }
        } else if (condition.startsWith("group:")) {
          const requiredGroup = condition.replace("group:", "").trim().toLowerCase();
          // Use the full group-name list serialized by the plugin (matches the
          // server-side permission check). currentUser.groups only contains
          // groups visible to the user, so it misses hidden/automatic groups.
          const userGroups =
            this.currentUser.avatar_frame_group_names ||
            (this.currentUser.groups || []).map((g) => g.name);
          const hasGroup = userGroups.some(
            (name) => name && name.toLowerCase() === requiredGroup
          );
          
          if (!hasGroup) {
            isLocked = true;
            lockedHint = I18n.t("avatar_frames.requires_group");
          }
        }
        
        framesList.push({ id, name, isLocked, lockedHint });
      }
    }
    
    return framesList;
  }

  @action
  async selectFrame(frame) {
    if (frame.isLocked) {
      return;
    }
    
    this.selectedFrame = frame.id;
    
    const customFields = Object.assign({}, this.currentUser.custom_fields, { 
      avatar_frame: frame.id === "none" ? null : frame.id 
    });
    
    try {
      await ajax(`/users/${this.currentUser.username}.json`, {
        type: "PUT",
        data: { custom_fields: customFields }
      });
      // Update local current user
      this.currentUser.set("custom_fields", customFields);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="control-group avatar-frame-preferences">
      <label class="control-label">{{i18n "avatar_frames.title"}}</label>
      <div class="controls">
        <div class="avatar-frame-grid">
          {{#each this.frames as |frame|}}
            <button
              type="button"
              class="avatar-frame-btn {{if (eq this.selectedFrame frame.id) 'is-selected'}} {{if frame.isLocked 'is-locked'}}"
              {{on "click" (fn this.selectFrame frame)}}
              disabled={{frame.isLocked}}
              title={{frame.lockedHint}}
            >
              <div class="preview-avatar-wrapper">
                <div class="post-avatar">
                  {{avatar this.currentUser imageSize="large"}}
                  {{#if (notEq frame.id "none")}}
                    <div class="avatar-frame-overlay frame-{{frame.id}}"></div>
                  {{/if}}
                </div>
              </div>
              <span class="frame-name">{{frame.name}}</span>
              {{#if frame.isLocked}}
                <span class="frame-hint">{{frame.lockedHint}}</span>
              {{/if}}
            </button>
          {{/each}}
        </div>
        <div class="instructions">
          {{i18n "avatar_frames.instructions"}}
        </div>
      </div>
    </div>
  </template>
}
