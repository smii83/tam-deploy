const PB_URL = 'http://127.0.0.1:8090';
fetch(PB_URL + '/api/collections/grades/records?perPage=200&sort=grade_number')
  .then(r => r.json())
  .then(d => {
    const items = d.items || [];
    items.filter(g => g.grade_number >= 11).forEach(g => 
      console.log(`grade=${g.grade_number} section="${g.section}" id=${g.id} name=${g.name_ar}`)
    );
  })
  .catch(e => console.error(e.message));
