#!/bin/dash

brew update && brew upgrade

brew install corepack
corepack enable && corepack prepare yarn@stable --activate

yarn dlx @yarnpkg/doctor
yarn dlx @anthropic-ai/claude-code
yarn dlx @yarnpkg/sdks vscode

rm -rf /opt/homebrew/bin/yarnpkg
rm -rf /opt/homebrew/bin/yarn
rm -rf /opt/homebrew/bin/pnpx
rm -rf /opt/homebrew/bin/pnpm

# sudo apt-get update && sudo apt-get install nodejs
# sudo corepack enable && sudo corepack prepare yarn@stable --activate
# yarn create next-app test-app --ts --use-yarn --eslint --tailwind --turbopack --no-app --import-alias="@/*" --src-dir
# cd test-app && yarn dlx @yarnpkg/sdks vscode && yarn add three && yarn add -D @types/three
# yarn install && yarn up && yarn dev