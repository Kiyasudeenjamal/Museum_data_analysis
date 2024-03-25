  -- 1. Fetch all the paintings which are not displayed on any museums?               
 select work_id,name as painting from work where museum_id is null;
---------------------------------------------------------------------------------------------
 -- 2. Are there museums without any paintings?
select m.* from museum m
left join work w 
on m.museum_id=w.museum_id
where w.work_id is null;
--------------------------------------------------------------------------------------------------------
-- 3. How many paintings have an asking price of more than their regular price?
 select * from product_size
where sale_price>regular_price;
---------------------------------------------------------------------------------------------------------------
 -- 4. Identify the paintings whose asking price is less than 50% of its regular price
select* from (select *,regular_price/2 as new from product_size) x
where sale_price<new;
------------------------------------------------------------------------------------------------------
 -- 5. Which canva size costs the most?
select c.size_id,c.width,c.height,c.label,p.sale_price from product_size p
join canvas_size c on p.size_id=c.size_id
where p.sale_price=(select max(sale_price) from product_size) ;
----------------------------------------------------------------------------------------------------------
-- 6. Delete duplicate records from work, product_size, subject and image_link tables
select * from(select *,row_number() over(partition by work_id order by work_id) as rk from work) as x
 where rk= 2;
delete from work
where row_num in(select row_num from(select *,row_number() over(partition by work_id order by work_id) as rk from work) as x
 where rk=2);
alter table work drop row_num;
---------------------------------------------------------------------------------
-- image_link
alter table image_link add column row_num int auto_increment primary key; 
delete from image_link
where row_num in (select row_num from(select *,row_number() over(partition by work_id order by work_id) as rk from image_link) as x
 where rk= 2);
alter table image_link drop row_num;
-----------------------------------------------------------------------------------
-- subject
alter table subject add column row_num int auto_increment primary key;
delete from subject
where row_num in (select row_num from(select *,row_number() over(partition by work_id,subject order by work_id) as rk from subject) as x
 where rk=2);
alter table subject drop row_num;
----------------------------------------
 -- product_size
 select row_num from(select *,row_number() over(partition by work_id, size_id, sale_price, regular_price order by work_id) as rk from product_size) as x
 where rk>1;
select * from product_size where work_id=181925;
alter table product_size add column row_num int auto_increment primary key;
delete from product_size
where row_num in (select row_num from(select *,row_number() over(partition by work_id, size_id, sale_price, regular_price order by work_id) as rk from product_size) as x
 where rk>1);
alter table product_size drop row_num;
-------------------------------------------------------------------------------------------------------------
 -- 7. Identify the museums with invalid city information in the given dataset
select * from museum
where city>0;
-----------------------------------------------------------------------------------------------------------
-- 8. Museum_Hours table has 1 invalid entry. Identify it and remove it.
select row_num from (select *,row_number() over(partition by museum_id,day order by day) as rk from museum_hours) x
where rk>1;
alter table museum_hours add column row_num int auto_increment primary key;
delete from museum_hours
where row_num in(select row_num from (select *,row_number() over(partition by museum_id,day order by day) as rk from museum_hours) x
where rk>1);
alter table museum_hours drop row_num ;
select * from museum_hours where museum_id=80;
-------------------------------------------------------------------------------------------------------
-- 9. Fetch the top 10 most famous painting subject
select * from 
(select *,rank() over(order by no_of_painting desc) as rank_num from 
(select subject,count(work_id) as no_of_painting from subject
group by subject order by no_of_painting desc ) v) x where rank_num<11;
--------------------------------------------------------------------------------------------------------
-- 10. Identify the museums which are open on both Sunday and Monday. Display museum name, city
with sun as(
select m.museum_id,m.name,m.city,m.state from museum m
join museum_hours mh
on m.museum_id=mh.museum_id
where mh.day='sunday'),
mon as (
select m.museum_id,m.name,m.city,m.state from museum m
join museum_hours mh
on m.museum_id=mh.museum_id
where mh.day='monday')
select distinct m.museum_id,m.name,m.city,m.state from mon m
join sun s 
on m.museum_id=s.museum_id;

select distinct m.name as museum_name, m.city, m.state,m.country
	from museum_hours mh 
	join museum m on m.museum_id=mh.museum_id
	where day='Sunday'
	and exists (select 1 from museum_hours mh2 
				where mh2.museum_id=mh.museum_id 
			    and mh2.day='Monday');
-------------------------------------------------------------------------------------------------
-- 11) How many museums are open every single day?
select m.museum_id,m.name
 from museum m inner join
(select *,row_number() over(partition by museum_id order by day) as rk from museum_hours) x
on m.museum_id=x.museum_id
where x.rk=7;
----------------------------------------------------------------------------------------------------
-- 12) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
with tab as(
select museum_id,count(work_id) c,row_number() over(order by count(work_id) desc) as rk from work 
group by museum_id 
having museum_id is not null limit 5)
select t.museum_id,m.name as Museum,m.city,t.rk from tab t
join museum m on t.museum_id=m.museum_id;
---------------------------------------------------------------------------------------------------------
-- 13) Who are the top 5 most popular artist? 
select a.first_name from (
select artist_id,count(work_id) as no_of_painting from work group by artist_id
order by no_of_painting desc limit 5) x
join artist as a
on x.artist_id=a.artist_id;
------------------------------------------------------------------------------------------------------------
 -- 14) Display the 3 least popular canva sizes 
with tab as(
select size_id,count(work_id) as no_of_painting
from product_size
group by size_id
),
main_tab as(
select t.size_id,c.label,t.no_of_painting,dense_rank() over(order by t.no_of_painting) as rk from tab t
join canvas_size c on
t.size_id=c.size_id)
select size_id,label,rk as Rank_num  from main_tab
where rk<=3; 
----------------------------------------------------------------------------------------
 -- 15) Which museum is open for the longest during a day. Dispay museum name, 
 -- state and hours open and which day?
with tab as(
select *,hour(TIMEDIFF(str_to_date(open,'%h:%i:%p'),str_to_date(close,'%h:%i:%p'))) as open_hours ,
dense_rank() over(order by hour(TIMEDIFF(str_to_date(open,'%h:%i:%p'),str_to_date(close,'%h:%i:%p'))) desc ) as rk
from museum_hours)
select t.museum_id,m.name as museum,t.open_hours
from tab t join museum m
on t.museum_id=m.museum_id
where t.rk=1;
-----------------------------------------------------------------------------------------
-- 16) Which museum has the most no of most popular painting style?
with tab as(
select museum_id,style,count(style) num from work
group by museum_id,style
having museum_id is not null
order by num desc
limit 1)
select m.name,t.museum_id,t.style,t.num as no_of_painting from tab t
join museum m
on t.museum_id=m.museum_id;
--------------------------------------------------------------------------------------------
 -- 17) Identify the artists whose paintings are displayed in multiple countries---
with tab as(
select artist_id,museum_id from(
select artist_id,museum_id,count(work_id) as cas,row_number() over(partition by artist_id) as rk from work
group by artist_id,museum_id
having museum_id is not null) x
where rk>1),
tab_2 as(
select t.*,m.country,row_number() over(partition by t.artist_id,country) as row_num from tab t
join museum m
on t.museum_id=m.museum_id),
tab_3 as(
select artist_id,count(artist_id) no_of_country from tab_2
where row_num=1
group by artist_id
having no_of_country>1)
select t.artist_id,a.full_name
from tab_3 t
join artist a 
on t.artist_id=a.artist_id;
-----------------------------------------------------------------------------------------------------
-- 18) Display the country and the city with most no of museums.  
select city,country,count(museum_id) no_museum from museum
group by city,country
order by no_museum desc limit 1;
----------------------------------------------------------------------------------------------------------
-- 19) Identify the artist and the museum where the most expensive and least expensive painting is placed. Display the artist name, sale_price, painting name,
-- museum name, museum city and canvas label
with tab as(
select * from product_size
where sale_price=(select max(sale_price) as most_exp from product_size)
union
select * from product_size
where sale_price=(select min(regular_price) as least_exp from product_size))
select a.full_name,t.sale_price,w.name as painting_name,m.name as museum_name,m.city,c.label from tab t
join work w
on t.work_id=w.work_id
join canvas_size c
on t.size_id=c.size_id
join artist a
on w.artist_id=a.artist_id
join museum m
on w.museum_id=m.museum_id
order by t.sale_price desc;
--------------------------------------------------------------------------------------------------------
 -- 20) Which country has the 5th highest no of paintings?
 with tab as(
select m.country,w.work_id  from work w
join museum m 
on w.museum_id=m.museum_id),
main_tab as(
select country,count(work_id) as no_of_painting,row_number() over(order by count(work_id) desc ) as rk  from tab
group by country)
select country, no_of_painting from main_tab
where rk=5
;
----------------------------------------------------------------------------------------------------------
 -- 21) Which are the 3 most popular and 3 least popular painting styles?
with tab_1 as(
select style,count(work_id) as no_of_painting from work where style is not null group by style
order by no_of_painting desc limit 3),
tab_2 as(
select * from (select style,count(work_id) as no_of_painting from work group by style
order by no_of_painting asc limit 3) x 
order by no_of_painting desc),
tab_3 as
(select * from tab_1
 union
 select * from tab_2)
select style,case
when x<=3 then 'Most Popular'
else 'Least Popular' end as remarks from 
(select *,row_number() over(order by no_of_painting desc ) as x from tab_3) X;
--------------------------------------------------------------------------------------------------------------
-- 22) Which artist has the most no of Portraits paintings outside USA?Display artist name, no of paintings and the artist nationality.
with tab_1 as(
select w.artist_id,count(s.work_id) as no_of_Portraits_paintings,
dense_rank() over(order by count(s.work_id) desc) as ran from work w
join (select work_id from subject where subject='Portraits') as s
on w.work_id=s.work_id
join (select * from museum where country !='usa') m 
on m.museum_id=w.museum_id
group by w.artist_id
)
select a.full_name as artist_name,t.no_of_Portraits_paintings,a.nationality from tab_1 t
join artist a
on t.artist_id=a.artist_id
where t.ran=1;














































         










 
                
                
                
                








































         
         
         
         
         
         
         
         
         
         
         
         
















































































































































