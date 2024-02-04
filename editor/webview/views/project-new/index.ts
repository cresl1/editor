import { FileTree } from "../file-tree";
import "./index.css";

import type { Project } from "../../../api/projects/types";
import type typeRPC from "../../../../src/webview";
import type api from "../../../api";

declare var rpc: typeof typeRPC<typeof api>;

export class ProjectNew {
    didCreateProjectAction: (newProject: Project) => void;
    cancelAction: () => void;

    async render() {
        const container = document.createElement("div");
        container.classList.add("project-new");

        // title
        const titleInputLabel = document.createElement("label");
        titleInputLabel.innerText = "Project Title";
        container.append(titleInputLabel);

        const titleInput = document.createElement("input");
        container.append(titleInput);


        // location
        const locationLabel = document.createElement("label");
        locationLabel.innerText = "Location";
        container.append(locationLabel);

        const fileTree = new FileTree()
        fileTree.directoryOnly = true;
        container.append(await fileTree.render())

        // buttons
        const buttonContainer = document.createElement("div");

        const cancelButton = document.createElement("button");
        cancelButton.classList.add("text")
        cancelButton.innerText = "Cancel";
        cancelButton.addEventListener("click", this.cancelAction);
        buttonContainer.append(cancelButton);

        const createButton = document.createElement("button");
        createButton.innerText = "Create";
        createButton.addEventListener("click", async () => {
            const projectBaseDirectory = fileTree.itemSelected
                ? fileTree.itemSelected.isDirectory
                    ? fileTree.itemSelected.path
                    : fileTree.itemSelected.path.slice(0, -1)
                : [];

            const location = [...projectBaseDirectory, titleInput.value].join("/");

            const project = await rpc().projects.create({
                title: titleInput.value,
                location
            });
            this.didCreateProjectAction(project);
        });
        buttonContainer.append(createButton);

        container.append(buttonContainer);

        return container;
    }
}