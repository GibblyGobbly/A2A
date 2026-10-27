<script>
  import { onMount } from 'svelte'

  const REPO = 'GibblyGobbly/A2A'
  const RELEASES = `https://github.com/${REPO}/releases/latest`

  // loading | ready | error
  let state = $state('loading')
  let release = $state(null)

  onMount(async () => {
    try {
      const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`)
      if (!res.ok) throw new Error(String(res.status))
      const data = await res.json()
      const apk = data.assets.find((a) => a.name.endsWith('.apk'))
      if (!apk) throw new Error('no apk')
      release = {
        version: data.tag_name.replace(/^v/, ''),
        url: apk.browser_download_url,
        size: (apk.size / 1048576).toFixed(0),
        sha: apk.digest ? apk.digest.replace('sha256:', '') : null
      }
      state = 'ready'
    } catch {
      state = 'error'
    }
  })

  // Material Icons paths (Apache 2.0)
  const features = [
    { title: 'Images', color: '#ffd84d',
      text: 'JPG, WEBP, PNG, BMP, GIF and ICO. Reads HEIC, AVIF and TIFF. Compress, resize, or combine into a PDF.',
      d: 'M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z' },
    { title: 'Video', color: '#7fd8c8',
      text: 'H.264, H.265, AV1, VP9, MKV and GIF. AV1 uses every CPU core. Compress by quality or target size.',
      d: 'M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z' },
    { title: 'Audio', color: '#8ec5ff',
      text: 'MP3, M4A, OPUS, OGG, FLAC and WAV. Pull the sound out of any video.',
      d: 'M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z' },
    { title: 'Documents', color: '#ff9ec7',
      text: 'PDF, DOCX, PPTX, TXT and Markdown in the directions that make sense. Merge several PDFs into one.',
      d: 'M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z' },
    { title: 'Fully offline', color: '#b49cff',
      text: 'The app has no internet permission, so nothing can leave your phone. Your originals are never changed.',
      d: 'M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zM9 8V6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9z' },
    { title: 'Batch and share', color: '#ffb067',
      text: 'Convert many files with progress and cancel. Share files into A2A from the gallery or any file manager.',
      d: 'M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z' }
  ]

  const steps = [
    'Download the APK on your phone.',
    'Open it and allow installs from your browser or file manager if Android asks.',
    'Open A2A and pick a file. Results are saved in Download/A2A.'
  ]
</script>

<header class="bar">
  <a class="brand" href="./">
    <img src="./logo.png" alt="" width="44" height="44" />
    <span>A2A</span>
  </a>
  <nav>
    <a class="chip" href="https://github.com/{REPO}">Source</a>
    <a class="chip" href="https://github.com/{REPO}#privacy">Privacy</a>
  </nav>
</header>

<main>
  <section class="hero">
    <div class="hero-text">
      <h1>Convert files <mark>offline</mark> on Android</h1>
      <p class="lead">Images, video, audio and documents, converted on your phone. Free and open source.</p>

      {#if state === 'ready'}
        <a class="btn" href={release.url}>
          <svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z" /></svg>
          Download {release.version}
        </a>
        <ul class="facts">
          <li>{release.size} MB</li>
          <li>Android 7.0+</li>
          <li>64-bit ARM and x64</li>
        </ul>
        {#if release.sha}
          <details>
            <summary>SHA-256 checksum</summary>
            <code>{release.sha}</code>
          </details>
        {/if}
      {:else if state === 'loading'}
        <span class="btn busy" aria-busy="true">Checking latest version</span>
      {:else}
        <a class="btn" href={RELEASES}>Open the latest release</a>
        <p class="note">Could not find a release yet. The release page has the APK once one is published.</p>
      {/if}
    </div>

    <img class="icon" src="./logo.png" alt="A2A app icon" width="240" height="240" />
  </section>

  <section>
    <h2>What it does</h2>
    <div class="grid">
      {#each features as f}
        <article class="tile" style="--tile: {f.color}">
          <svg viewBox="0 0 24 24" width="28" height="28" aria-hidden="true"><path d={f.d} /></svg>
          <h3>{f.title}</h3>
          <p>{f.text}</p>
        </article>
      {/each}
    </div>
    <p class="plain">No accounts. No analytics. No ads.</p>
  </section>

  <section>
    <h2>Install</h2>
    <ol class="steps">
      {#each steps as s}
        <li>{s}</li>
      {/each}
    </ol>
  </section>
</main>

<section class="license">
  <div>
    <h2>Free software, GPL v3</h2>
    <p>
      A2A is released under the
      <a href="https://github.com/{REPO}/blob/main/LICENSE">GNU General Public License v3.0 or later</a>.
      You can use, study, change and share it.
      <a href="https://github.com/{REPO}">Read the source on GitHub.</a>
    </p>
  </div>
</section>

<footer>
  <p>Copyright 2024-2026 Gibbly Gobbly. Typeface Space Grotesk (<a href="./licenses/SpaceGrotesk-OFL.txt">OFL 1.1</a>).</p>
</footer>
