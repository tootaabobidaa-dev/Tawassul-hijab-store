export default async function handler(req, res) {
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

  const SITE_URL =
    "https://tawassul-hijab-store-v2-seven.vercel.app";

  try {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/products?select=id`,
      {
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
        },
      }
    );

    if (!response.ok) {
      throw new Error("Failed to load products");
    }

    const products = await response.json();

    const urls = [
      `<url>
        <loc>${SITE_URL}/</loc>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
      </url>`,

      `<url>
        <loc>${SITE_URL}/products</loc>
        <changefreq>daily</changefreq>
        <priority>0.9</priority>
      </url>`
    ];

    products.forEach(product => {
      if (product.id) {
        urls.push(`
          <url>
            <loc>${SITE_URL}/products/${encodeURIComponent(product.id)}</loc>
            <changefreq>weekly</changefreq>
            <priority>0.8</priority>
          </url>
        `);
      }
    });

    const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.join("\n")}
</urlset>`;

    res.setHeader(
      "Content-Type",
      "application/xml; charset=utf-8"
    );

    res.setHeader(
      "Cache-Control",
      "s-maxage=3600, stale-while-revalidate=86400"
    );

    return res.status(200).send(sitemap);

  } catch (error) {
    console.error(error);

    return res
      .status(500)
      .send("Unable to generate sitemap");
  }
      }
