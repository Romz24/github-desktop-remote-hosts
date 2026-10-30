# GitHub Desktop: "View on GitLab" (and Bitbucket, Gitea) for repositories that are not on GitHub.
#
#   patch.bat            - patch GitHub Desktop (close it first, run again after every update)
#   patch.bat -Restore   - undo
#
# GitHub Desktop is plain JavaScript in %LOCALAPPDATA%\GitHubDesktop\app-x.y.z\resources\app.
# We add a few helper functions to renderer.js and make small text replacements in the minified
# main.js / renderer.js. Originals are kept as main.js.orig / renderer.js.orig.

param(
  [string]$AppDir,     # optional: a specific app-x.y.z folder instead of the newest one
  [switch]$Restore
)
$ErrorActionPreference = 'Stop'

# Helpers available to GitHub Desktop's code as `remoteHosts.*`.
$helpers = @'
/* github-desktop-remote-hosts */
window.remoteHosts = (() => {
  // Remote URL -> web page of the repository:
  //   git@gitlab.com:group/repo.git, ssh://git@host:2222/group/repo.git, https://host/group/repo.git
  //   -> https://host/group/repo
  function web(remoteUrl) {
    if (!remoteUrl) return null;
    remoteUrl = remoteUrl.trim();
    let protocol = 'https:', host, path;
    const scp = /^[\w.-]+@([^:/]+):(?!\/\/)(.+)$/.exec(remoteUrl);   // git@host:group/repo.git
    if (scp) {
      host = scp[1];
      path = scp[2];
    } else {
      let url;
      try { url = new URL(remoteUrl); } catch (e) { return null; }
      if (url.protocol === 'http:' || url.protocol === 'https:') {
        protocol = url.protocol;
        host = url.host;                 // keeps a custom web port
      } else if (url.protocol === 'ssh:' || url.protocol === 'git:') {
        host = url.hostname;             // an ssh port is not a web port
      } else {
        return null;                     // local folder, file://, ...
      }
      path = url.pathname;
    }
    path = path.replace(/^\/+|\/+$/g, '').replace(/\.git$/, '');
    return host && path ? `${protocol}//${host}/${path}` : null;
  }

  // Which site it is, by host name. Unknown hosts are taken for self-hosted GitLab.
  function site(webUrl) {
    const host = new URL(webUrl).hostname;
    if (host.includes('github')) return 'GitHub';
    if (host.includes('bitbucket')) return 'Bitbucket';
    if (host.includes('gitea') || host.includes('codeberg') || host.includes('forgejo')) return 'Gitea';
    return 'GitLab';
  }

  // action is 'tree' (View branch) or 'compare' (Compare)
  function branchURL(webUrl, action, branch, defaultBranch) {
    const b = encodeURIComponent(branch);
    const d = encodeURIComponent(defaultBranch ? defaultBranch.nameWithoutRemote : 'main');
    switch (site(webUrl)) {
      case 'GitLab':    return action === 'tree' ? `${webUrl}/-/tree/${b}`      : `${webUrl}/-/compare/${d}...${b}`;
      case 'Bitbucket': return action === 'tree' ? `${webUrl}/src/${b}`         : `${webUrl}/branches/compare/${b}%0D${d}`;
      case 'Gitea':     return action === 'tree' ? `${webUrl}/src/branch/${b}`  : `${webUrl}/compare/${d}...${b}`;
      default:          return `${webUrl}/${action}/${b}`;
    }
  }

  // file (optional): scroll to that file in the commit
  function commitURL(webUrl, sha, file) {
    switch (site(webUrl)) {
      case 'GitLab':
        // GitLab marks each file in a commit with the SHA-1 of its path.
        const anchor = file ? '#' + require('crypto').createHash('sha1').update(file).digest('hex') : '';
        return `${webUrl}/-/commit/${sha}${anchor}`;
      case 'Bitbucket': return `${webUrl}/commits/${sha}`;
      default:          return `${webUrl}/commit/${sha}`;
    }
  }

  function issueURL(webUrl) {
    return site(webUrl) === 'GitLab' ? `${webUrl}/-/issues/new` : `${webUrl}/issues/new`;
  }

  // Web page of the selected repository if it is not a GitHub one.
  // repo (optional): only if it is the selected repository.
  function fromState(selectedState, repo) {
    const selected = selectedState && selectedState.repository;
    if (!selected || selected.gitHubRepository || !selectedState.state) return null;
    if (repo && repo.id !== selected.id) return null;
    return web(selectedState.state.remote && selectedState.state.remote.url);
  }

  // The app tells us about the selected repository when it updates the menu (see track below);
  // parts of the UI that only know about GitHub read it back with current().
  let selected = null;   // { id, url, label }

  // Returns the name for the menu: "GitHub", "GitLab", ...
  function track(repo, repoState) {
    const url = repo && !repo.gitHubRepository && repoState ? web(repoState.remote && repoState.remote.url) : null;
    selected = url ? { id: repo.id, url: url, label: site(url) } : null;
    return selected ? selected.label : 'GitHub';
  }

  // repo (optional): only if it is the selected repository.
  function current(repo) {
    return selected && (!repo || repo.id === selected.id) ? selected : null;
  }

  return { web, site, branchURL, commitURL, issueURL, fromState, track, current };
})();

'@

# main.js: menu labels. __rh is the host name sent by renderer.js ("GitHub", "GitLab", ...).
$mainChanges = @(
  @('isChangesFilterVisible:c=!0}){',
    'isChangesFilterVisible:c=!0,remoteHostName:__rh="GitHub"}){'),
  @('label:"&View on GitHub"',          'label:`&View on ${__rh}`'),
  @('label:"Create &issue on GitHub"',  'label:`Create &issue on ${__rh}`'),
  @('label:"Compare on &GitHub"',       'label:`Compare on &${__rh}`'),
  @('label:"View branch on GitHub"',    'label:`View branch on ${__rh}`')
)

$rendererChanges = @(
  # Send the host name to the menu (and remember the selected repository).
  @('askForConfirmationOnForcePush:a};',
    'askForConfirmationOnForcePush:a,remoteHostName:remoteHosts.track(s,e)};'),

  # Menu: enable the items when the repository has a non-GitHub remote.
  @('b.setEnabled("view-repository-on-github",n)',
    'b.setEnabled("view-repository-on-github",n||!!remoteHosts.fromState(t))'),
  @('b.setEnabled("create-issue-in-repository-on-github",v)',
    'b.setEnabled("create-issue-in-repository-on-github",v||!!remoteHosts.fromState(t))'),
  @('b.setEnabled("compare-on-github",n&&h)',
    'b.setEnabled("compare-on-github",(n||!!remoteHosts.fromState(t))&&h)'),
  @('b.setEnabled("branch-on-github",n&&h)',
    'b.setEnabled("branch-on-github",(n||!!remoteHosts.fromState(t))&&h)'),

  # Repository > View on ...
  @('const t=Lo(e);t&&this.props.dispatcher.openInBrowser(t)}',
    'const t=Lo(e)||remoteHosts.fromState(this.state.selectedState,e);t&&this.props.dispatcher.openInBrowser(t)}'),

  # Repository > Create issue on ...
  @('e instanceof Mo&&this.props.dispatcher.openIssueCreationPage(e)}',
    'e instanceof Mo&&(e.gitHubRepository?this.props.dispatcher.openIssueCreationPage(e):this.props.dispatcher.openInBrowser(remoteHosts.issueURL(remoteHosts.fromState(this.state.selectedState,e))))}'),

  # Branch > View branch on ... / Compare on ...
  @('return!e||e instanceof Vo||!e.gitHubRepository?null:e.gitHubRepository.htmlURL}',
    'return!e||e instanceof Vo?null:e.gitHubRepository?e.gitHubRepository.htmlURL:remoteHosts.fromState(this.state.selectedState,e)}'),
  @('const i=`${t}/${e}/${encodeURIComponent(s.branch.upstreamWithoutRemote)}`;',
    'const i=this.getRepository().gitHubRepository?`${t}/${e}/${encodeURIComponent(s.branch.upstreamWithoutRemote)}`:remoteHosts.branchURL(t,e,s.branch.upstreamWithoutRemote,n.state.branchesState.defaultBranch);'),

  # "No local changes" screen: "Open the repository page on ... in your browser"
  @('renderViewOnGitHub(){return null!==this.props.repository.gitHubRepository?this.renderMenuBackedAction("view-repository-on-github","Open the repository page on GitHub in your browser",',
    'renderViewOnGitHub(){const w=this.props.repository.gitHubRepository?null:remoteHosts.web(this.props.repositoryState.remote?.url);return this.props.repository.gitHubRepository||w?this.renderMenuBackedAction("view-repository-on-github",`Open the repository page on ${w?remoteHosts.site(w):"GitHub"} in your browser`,'),

  # History: right click on a commit, and on a file of a commit.
  # current() has a `label` and no `endpoint`, which tells it apart from a GitHub repository.
  @('const c=this.props.gitHubRepository;',
    'const c=this.props.gitHubRepository||remoteHosts.current();'),
  @('c&&c.endpoint!==Wr()&&(l="View on GitHub Enterprise")',
    'c&&c.endpoint!==Wr()&&(l=c.endpoint?"View on GitHub Enterprise":"View on "+c.label)'),
  @('const u=i.gitHubRepository;',
    'const u=i.gitHubRepository||remoteHosts.current(i);'),
  @('u&&u.endpoint!==Wr()&&(h="View on GitHub Enterprise")',
    'u&&u.endpoint!==Wr()&&(h=u.endpoint?"View on GitHub Enterprise":"View on "+u.label)'),
  @('if(!n||n instanceof Vo||!n.gitHubRepository)return;const s=cK(n.gitHubRepository,e,t);',
    'if(!n||n instanceof Vo)return;const s=n.gitHubRepository?cK(n.gitHubRepository,e,t):remoteHosts.commitURL(remoteHosts.fromState(this.state.selectedState,n),e,t);'),

  # Repository list: right click on the selected repository.
  @('s=t instanceof Mo&&null!=t.gitHubRepository,',
    's=t instanceof Mo&&(null!=t.gitHubRepository||!!remoteHosts.current(t)),'),
  @('{label:"View on GitHub",action:()=>e.onViewOnGitHub(t)',
    '{label:"View on "+(remoteHosts.current(t)?.label??"GitHub"),action:()=>e.onViewOnGitHub(t)')
)

# Apply the replacements to the original text. Each one must be found exactly once,
# otherwise this GitHub Desktop version has different code and nothing is written.
function Apply-Changes($text, $changes, $file) {
  foreach ($change in $changes) {
    $find, $replace = $change
    $count = [regex]::Matches($text, [regex]::Escape($find)).Count
    if ($count -ne 1) {
      throw "${file}: found $count times instead of 1: $find`nThis GitHub Desktop version needs the patch updated. Nothing was changed."
    }
    $text = $text.Replace($find, $replace)
  }
  return $text
}

try {
  if (-not $AppDir) {
    $AppDir = (Get-ChildItem "$env:LOCALAPPDATA\GitHubDesktop\app-*" -Directory |
      Sort-Object { [version]$_.Name.Substring(4) } | Select-Object -Last 1).FullName
    if (-not $AppDir) { throw 'GitHub Desktop is not installed.' }
  }
  $main = Join-Path $AppDir 'resources\app\main.js'
  $renderer = Join-Path $AppDir 'resources\app\renderer.js'
  Write-Host "GitHub Desktop: $AppDir"

  if ($Restore) {
    foreach ($file in $main, $renderer) {
      if (Test-Path "$file.orig") { Copy-Item "$file.orig" $file -Force }
    }
    Write-Host 'Restored. Restart GitHub Desktop.'
    exit
  }

  # Always patch the original, so running again (or a newer patch) is safe.
  foreach ($file in $main, $renderer) {
    if (-not (Test-Path "$file.orig")) { Copy-Item $file "$file.orig" }
  }
  $newMain = Apply-Changes ([IO.File]::ReadAllText("$main.orig")) $mainChanges 'main.js'
  $newRenderer = $helpers + (Apply-Changes ([IO.File]::ReadAllText("$renderer.orig")) $rendererChanges 'renderer.js')

  [IO.File]::WriteAllText($main, $newMain)
  [IO.File]::WriteAllText($renderer, $newRenderer)
  Write-Host 'Patched. Restart GitHub Desktop.'
} catch {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
