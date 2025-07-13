# Colab 部署

此部署方式利用 Colab 的 Notebook 环境运行，并**强制要求启用 GitHub 同步**功能以实现数据持久化。

注意，由于 Colab 的特性，此部署方式无法做到持续运行，每次运行后退出网页，实例最长运行90分钟。但此方法拥有以下显著优点：

* 无门槛，只要有 Google 帐号即可使用
* 部署简单，通过笔记本一键部署运行
* 最大化利用 GitHub 同步功能，实现数据的持久保存


1. **准备 GitHub 仓库和 PAT**:
   
   * 你需要一个**自己的** GitHub 仓库来存储同步的数据。建议使用私有仓库。
   * 创建一个 GitHub Personal Access Token (PAT)，并确保勾选了 `repo` 权限范围。**请妥善保管此 Token**。
   * 具体操作步骤详见[GitHub配置同步教程](../GitHub/GitHub同步.md)

2. **保存 Colab 笔记本**:
   点击[![Open In Colab](202507131855.svg)](https://colab.research.google.com/github/dreamhartley/JimiHub/blob/main/doc/Deploy/Colab/colab启动.ipynb)保存笔记本到自己的Google Drive中。
